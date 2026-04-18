;; LedgeRPG ↔ MAGUS adapter — bridges the paper-MVP scoring call.
;;
;; Responsibilities (in order of load-bearing-ness for the paper):
;;
;; 1. Declare the two LedgeRPG goals as MAGUS `Goal` instances so they can
;;    appear in ScoringContext.
;; 2. Provide a per-candidate antigoal so stock `score-decision-v2` produces
;;    scores that differ by action. Without this the antigoal-factor is 1.0
;;    for every candidate and all actions tie at base utility.
;; 3. Provide a HERMES hook: an attribution-space plus a wrapper
;;    `score-decision-v2-hermes` that folds a per-action bonus into the
;;    stock DecisionScore's final field. The stock `score-decision-v2`
;;    is NOT modified — this file is purely additive.
;;
;; Hyperon 0.2.x quirks observed:
;;
;; - `cond` is non-reducing in MAGUS's pinned 0.2.1 — this file uses nested
;;   `if` and `match`-on-knowledge-base patterns only.
;;
;; - In 0.2.10 (what HERMES pip-installs), `!(bind! &s (new-space))` does NOT
;;   clear atoms from an already-bound space. The Python driver
;;   (`HyperonScorer._publish_goal_state` / `update_attributions`) works
;;   around this with explicit `match + remove-atom` before each rebind.
;;   Do NOT rely on bind!+new-space as a clear primitive; it is a no-op on
;;   a live space.
;;
;; - Every equation in this file must have mutually exclusive patterns.
;;   A `$_` or `$other` catchall alongside a specific equation causes MeTTa's
;;   rewriter to reduce both, emitting duplicate `(decision-score ...)` atoms
;;   at the call site. See `action-is-move` for the explicit-enumeration
;;   discipline this requires.

;; =============================================================================
;; LedgeRPG Goal Instances
;; =============================================================================

;; priority, weight chosen so EXPLORATION_INCENTIVE nudges toward discovery
;; and ENERGY_REGULATION acts as a survival floor. Numbers are intentionally
;; simple and declarative — they are not tuning knobs for the paper.
(= (ledgerpg-exploration-goal) (goal EXPLORATION_INCENTIVE 0.7 0.6))
(= (ledgerpg-energy-goal)      (goal ENERGY_REGULATION 0.9 0.8))

(= (ledgerpg-goals)
   (Cons (ledgerpg-exploration-goal)
         (Cons (ledgerpg-energy-goal)
               Nil)))

;; =============================================================================
;; Goal-state knowledge base (populated per-step from the server trace)
;; =============================================================================
;;
;; The MAGUS ScoringContext's Goal atoms carry priority/weight, not live
;; satisfaction. The driver publishes live values here before each scoring
;; call so considerations/antigoals can read them.
!(bind! &ledgerpg-goal-state (new-space))

;; Lookup helper: returns the live value for a goal name, or a default.
(: ledgerpg-goal-value (-> Symbol Number Number))
(= (ledgerpg-goal-value $name $default)
   (let $v (match &ledgerpg-goal-state (goal-value $name $x) $x)
     (if (== $v ()) $default $v)))

;; =============================================================================
;; Per-candidate differentiation: a single antigoal
;; =============================================================================
;;
;; The antigoal factor is multiplicative in [0, 1]. We penalize move-* actions
;; when energy is low (below 0.3), because moving costs energy and doing so
;; near the floor is the clearest inefficient decision in LedgeRPG. `examine`
;; and `rest` get the neutral 1.0 factor.
;;
;; Penalty shape: factor = 1.0 - clamp((0.3 - energy) / 0.3, 0, 1) * 0.5
;; so at energy=0.3 factor=1.0, at energy=0.0 factor=0.5 for moves.

;; Enumerated explicitly for all 8 LedgeRPG actions so exactly one equation
;; matches any given action symbol. A `$_` catchall would cause MeTTa to
;; reduce both the specific and the catchall, duplicating downstream results.
(: action-is-move (-> Symbol Bool))
(= (action-is-move move-N) True)
(= (action-is-move move-NE) True)
(= (action-is-move move-SE) True)
(= (action-is-move move-S) True)
(= (action-is-move move-SW) True)
(= (action-is-move move-NW) True)
(= (action-is-move examine) False)
(= (action-is-move rest) False)

(: clamp01 (-> Number Number))
(= (clamp01 $x)
   (if (< $x 0) 0
       (if (> $x 1) 1 $x)))

;; LedgeRPG only ever submits action-candidate inputs. If you add goal-candidate
;; paths later, extend this with a second equation — do not add a generic
;; `$other` fallback, because MeTTa's rewriter would explore both paths and
;; emit duplicate identical results.
(: ledgerpg-move-when-low-energy-penalty (-> Context Candidate Number))
(= (ledgerpg-move-when-low-energy-penalty $ctx (action-candidate (action $name $params)))
   (let* (($energy (ledgerpg-goal-value ENERGY_REGULATION 1.0))
          ($depletion (clamp01 (/ (- 0.3 $energy) 0.3))))
     (if (action-is-move $name)
         (- 1.0 (* 0.5 $depletion))
         1.0)))

;; Tile-aware examine penalty: examining an empty tile is a wasted step, but
;; examining a food/wall tile yields information. Without this, every action
;; ties at final=1.0 in early game and the Python tiebreak locks the agent
;; into examine-forever.

(: ledgerpg-tile-type (-> Symbol Symbol))
(= (ledgerpg-tile-type $default)
   (let $t (match &ledgerpg-goal-state (tile-type $x) $x)
     (if (== $t ()) $default $t)))

(: examine-penalty-for-tile (-> Symbol Number))
(= (examine-penalty-for-tile empty) 0.3)
(= (examine-penalty-for-tile wall)  1.0)
(= (examine-penalty-for-tile food)  1.0)
(= (examine-penalty-for-tile obstacle) 1.0)

(: ledgerpg-examine-on-empty-penalty (-> Context Candidate Number))
(= (ledgerpg-examine-on-empty-penalty $ctx (action-candidate (action $name $params)))
   (if (== $name examine)
       (examine-penalty-for-tile (ledgerpg-tile-type empty))
       1.0))

(= (ledgerpg-antigoals)
   (Cons (anti-goal move-when-low-energy Soft ledgerpg-move-when-low-energy-penalty)
         (Cons (anti-goal examine-on-empty Soft ledgerpg-examine-on-empty-penalty)
               Nil)))

;; =============================================================================
;; Base utility: one context-dependent consideration
;; =============================================================================
;;
;; Considerations don't see the candidate, so this only sets a baseline nonzero
;; utility; per-action differentiation comes from the antigoal above and the
;; HERMES bonus below. Formula: reward unsatisfied goals, so the agent has
;; positive utility to act at all.

(: ledgerpg-exploration-pressure (-> ScoringContext Number))
(= (ledgerpg-exploration-pressure $ctx)
   (- 1.0 (ledgerpg-goal-value EXPLORATION_INCENTIVE 0.0)))

(: ledgerpg-energy-pressure (-> ScoringContext Number))
(= (ledgerpg-energy-pressure $ctx)
   (- 1.0 (ledgerpg-goal-value ENERGY_REGULATION 1.0)))

(= (ledgerpg-considerations)
   (Cons (consideration exploration-pressure ledgerpg-exploration-pressure)
         (Cons (consideration energy-pressure ledgerpg-energy-pressure)
               Nil)))

(= (ledgerpg-discouragements) Nil)
(= (ledgerpg-metagoals) Nil)

;; =============================================================================
;; HERMES attribution-space + bonus lookup
;; =============================================================================
;;
;; The Python driver injects one atom per SignedAttribution before each
;; scoring call:
;;   (attribution <action-name> <goal-name> <lag> <signed-weight> <confidence>)
;;
;; The wrapper below pulls every match for a given action-name, aggregates
;; (signed_weight * confidence) across goals, and scales by ATTRIBUTION-SCALE.
;; This is the symbolic equivalent of `build_bias_table` in bias.py — kept in
;; MeTTa per Option B so MAGUS reads HERMES state from its own working memory.

!(bind! &ledgerpg-attribution-space (new-space))

;; Originally 0.1. Halved to 0.05 in combination with Python-side
;; group-mean-centered attributions produced too weak a feedback signal:
;; 25/30 EXPLORATION losses (down from 29/30 under the uncentered 0.1 run).
;; Restored to 0.1 so the centering's relative-advantage signal has enough
;; magnitude to flip tie-ordering at the candidate-selection step.
(= (ledgerpg-attribution-scale) 0.1)

;; Per-attribution term: signed_weight * confidence * (1 / lag).
;; The 1/lag factor is a no-op at the paper's lag=1 but makes the framework
;; lag-aware for any future multi-step attribution extension.
(: ledgerpg-attribution-term (-> Number Number Number Number))
(= (ledgerpg-attribution-term $signed-w $conf $lag)
   (if (> $lag 0)
       (/ (* $signed-w $conf) $lag)
       0))

(: ledgerpg-attribution-bonus-for (-> Symbol Number))
(= (ledgerpg-attribution-bonus-for $action-name)
   (let $terms
     (collapse
       (match &ledgerpg-attribution-space
         (attribution $action-name $goal $lag $signed-w $conf)
         (ledgerpg-attribution-term $signed-w $conf $lag)))
     (if (== $terms ())
         0
         (* (ledgerpg-attribution-scale)
            (foldl-atom $terms 0 $acc $x (+ $acc $x))))))

(: ledgerpg-candidate-bonus (-> Candidate Number))
(= (ledgerpg-candidate-bonus (action-candidate (action $name $params)))
   (ledgerpg-attribution-bonus-for $name))

;; =============================================================================
;; score-decision-v2-hermes — HERMES-aware wrapper around the stock scorer
;; =============================================================================
;;
;; Stock score-decision-v2 returns (decision-score base meta over anti final).
;; We leave those four fields alone and add the HERMES bonus into `final` so
;; the per-action contribution is visible both as a separate atom
;; (via ledgerpg-score-breakdown-hermes) and folded into the comparable
;; final score.

(: score-decision-v2-hermes (-> Candidate
                                (List Consideration)
                                (List Discouragement)
                                (List Metagoal)
                                (List AntiGoal)
                                ScoringContext
                                DecisionScore))
(= (score-decision-v2-hermes $cand $cons $dis $meta $anti $ctx)
   (let* (($stock (score-decision-v2 $cand $cons $dis $meta $anti $ctx))
          ($bonus (ledgerpg-candidate-bonus $cand)))
     (ledgerpg-add-hermes-bonus $stock $bonus)))

(: ledgerpg-add-hermes-bonus (-> DecisionScore Number DecisionScore))
(= (ledgerpg-add-hermes-bonus (decision-score $b $m $o $a $f) $bonus)
   (decision-score $b $m $o $a (+ $f $bonus)))

;; Diagnostic: return the bonus alongside the stock breakdown, for the driver's
;; per-step decomposition log. A 6-tuple: (base, meta, over, anti, hermes, final).
(: score-decision-v2-hermes-breakdown (-> Candidate
                                          (List Consideration)
                                          (List Discouragement)
                                          (List Metagoal)
                                          (List AntiGoal)
                                          ScoringContext
                                          Expression))
(= (score-decision-v2-hermes-breakdown $cand $cons $dis $meta $anti $ctx)
   (let* (($stock (score-decision-v2 $cand $cons $dis $meta $anti $ctx))
          ($bonus (ledgerpg-candidate-bonus $cand)))
     (ledgerpg-breakdown-of $stock $bonus)))

(: ledgerpg-breakdown-of (-> DecisionScore Number Expression))
(= (ledgerpg-breakdown-of (decision-score $b $m $o $a $f) $bonus)
   (breakdown $b $m $o $a $bonus (+ $f $bonus)))
