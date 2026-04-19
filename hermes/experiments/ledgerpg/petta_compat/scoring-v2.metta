;; MAGUS Milestone 3: Scoring v2 Module (Refined)
;; Integrates base utility, metagoal adjustments, and anti-goal penalties
;; Provides explainability through structured score breakdowns
;; Based on Milestone-3-Spec.md requirements and M3-Refinement-Plan.md

;; Import shared types
!(load types.metta)

;; Import other modules
!(load metagoals.metta)
!(load antigoals.metta)
!(load overgoal.metta)

;; =============================================================================
;; Additional Types (beyond types.metta)
;; =============================================================================

;; Types are already defined in types.metta, just adding any missing ones here

;; =============================================================================
;; Base Utility Calculation (from v1)
;; =============================================================================

;; Calculate base utility from considerations and discouragements
(= (calculate-base-utility $considerations $discouragements $context)
   (let* (($con-score (sum-considerations $considerations $context))
          ($dis-score (sum-discouragements $discouragements $context))
          ($modulated (apply-modulators (- $con-score $dis-score)
                                       (get-modulators $context))))
     $modulated))

;; Sum consideration scores
(= (sum-considerations Nil $context) 0)
(= (sum-considerations (Cons (consideration $name $fn) $tail) $context)
   (+ ($fn $context) (sum-considerations $tail $context)))

;; Sum discouragement scores
(= (sum-discouragements Nil $context) 0)
(= (sum-discouragements (Cons (discouragement $name $fn) $tail) $context)
   (+ ($fn $context) (sum-discouragements $tail $context)))

;; Get modulators from context
(= (get-modulators (scoring-context $goals $modulators $time)) $modulators)

;; Apply modulators to base score
(= (apply-modulators $score Nil) $score)
(= (apply-modulators $score (Cons (modulator $name $value) $tail))
   (let* (($modulated (* $score (modulator-effect $name $value))))
     (apply-modulators $modulated $tail)))

;; Calculate modulator effect - Bach's 6-modulator framework
;; PAD (Pleasure-Arousal-Dominance) + Attentional (Focus, Resolution, Exteroception)
;; Using knowledge base approach to avoid nondeterminism from catch-all pattern

;; Create modulator knowledge base
!(bind! &modulator-kb (new-space))

;; Store modulator parameters: (modulator-params name base-value multiplier)
;; Formula: effect = base + (multiplier × value)
!(add-atom &modulator-kb (modulator-params arousal 0.8 0.4))       ;; 0.8 to 1.2
!(add-atom &modulator-kb (modulator-params pleasure 0.9 0.2))      ;; 0.9 to 1.1
!(add-atom &modulator-kb (modulator-params dominance 0.85 0.3))    ;; 0.85 to 1.15
!(add-atom &modulator-kb (modulator-params focus 0.7 0.6))         ;; 0.7 to 1.3
!(add-atom &modulator-kb (modulator-params resolution 0.75 0.5))   ;; 0.75 to 1.25
!(add-atom &modulator-kb (modulator-params exteroception 0.8 0.4)) ;; 0.8 to 1.2

;; Get modulator effect by looking up parameters
(= (modulator-effect $name $value)
   (let $params (match &modulator-kb (modulator-params $name $base $mult) ($base $mult))
     (if (== $params ())
         1.0  ;; Default for unknown modulators
         (let ($base $mult) $params
           (+ $base (* $mult $value))))))

;; =============================================================================
;; Metagoal Integration
;; =============================================================================

;; Named helper for metagoal magus-fold operation
(= (metagoal-score-helper $metagoal $goal $context $acc)
   (+ $acc (single-metagoal-score $goal $context $metagoal)))

;; Calculate metagoal adjustment using imported functions
(= (calculate-metagoal-adjustment-v2 $goal $context Nil) 0)
(= (calculate-metagoal-adjustment-v2 $goal $context (Cons $metagoal $tail))
   (+ (single-metagoal-score $goal $context $metagoal)
      (calculate-metagoal-adjustment-v2 $goal $context $tail)))

;; Calculate single metagoal contribution
(= (single-metagoal-score $goal $context (metagoal coherence))
   (* 0.1 (goal-coherence-score $goal $context)))
(= (single-metagoal-score $goal $context (metagoal efficiency))
   (* -0.05 (goal-inefficiency-score $goal $context)))
(= (single-metagoal-score $goal $context (metagoal learning))
   (* 0.15 (goal-novelty-score $goal $context)))
(= (single-metagoal-score $goal $context (metagoal uncertainty-reduction))
   (* 0.1 (goal-uncertainty-value $goal $context)))

;; Goal coherence score - measures compatibility with other goals
(= (goal-coherence-score $goal (scoring-context $goals $mods $time))
   (count-coherent-goals $goal $goals))

;; Count coherent goals
(= (count-coherent-goals $goal Nil) 0)
(= (count-coherent-goals $goal (Cons $other $tail))
   (if (goals-compatible $goal $other)
       (+ 1 (count-coherent-goals $goal $tail))
       (count-coherent-goals $goal $tail)))

;; Check goal compatibility based on goal names
(= (goals-compatible (goal $n1 $p1 $w1) (goal $n2 $p2 $w2))
   (check-goal-synergy $n1 $n2))

;; Goal synergy rules
(= (check-goal-synergy explore discover) True)
(= (check-goal-synergy discover learn) True)
(= (check-goal-synergy survive defend) True)
(= (check-goal-synergy attack dominate) True)
(= (check-goal-synergy build create) True)
(= (check-goal-synergy gather prepare) True)
(= (check-goal-synergy $g1 $g2)
   (if (== $g1 $g2) False False))  ;; Same goals don't synergize, different goals default to no synergy

;; Goal inefficiency score - estimates resource cost
(= (goal-inefficiency-score (goal $name $priority $weight) $context)
   (estimate-goal-cost $name $priority $weight))

;; Estimate resource cost of a goal
(= (estimate-goal-cost explore $p $w) (* $w 1.5))   ;; Medium cost
(= (estimate-goal-cost attack $p $w) (* $w 2.5))    ;; High cost
(= (estimate-goal-cost defend $p $w) (* $w 2.0))    ;; High cost
(= (estimate-goal-cost gather $p $w) (* $w 1.2))    ;; Low-medium cost
(= (estimate-goal-cost build $p $w) (* $w 3.0))     ;; Very high cost
(= (estimate-goal-cost learn $p $w) (* $w 0.8))     ;; Low cost
(= (estimate-goal-cost survive $p $w) (* $w 0.5))   ;; Very low cost
(= (estimate-goal-cost $other $p $w) (* $w 1.0))    ;; Default cost

;; Goal novelty score - measures unexplored potential
(= (goal-novelty-score (goal $name $priority $weight) $context)
   (calculate-novelty $name $context))

;; Calculate novelty based on goal type and context
(= (calculate-novelty explore $context) 0.8)    ;; High novelty
(= (calculate-novelty discover $context) 0.9)   ;; Very high novelty
(= (calculate-novelty learn $context) 0.7)      ;; High novelty
(= (calculate-novelty experiment $context) 1.0) ;; Maximum novelty
(= (calculate-novelty build $context) 0.5)      ;; Medium novelty
(= (calculate-novelty $routine $context) 0.2)   ;; Low novelty for routine goals

;; Goal uncertainty reduction value
(= (goal-uncertainty-value (goal $name $priority $weight) $context)
   (estimate-info-gain $name $priority))

;; Estimate information gain from achieving goal
(= (estimate-info-gain explore $p) (* $p 0.6))
(= (estimate-info-gain scout $p) (* $p 0.7))
(= (estimate-info-gain investigate $p) (* $p 0.8))
(= (estimate-info-gain analyze $p) (* $p 0.9))
(= (estimate-info-gain test $p) (* $p 0.5))
(= (estimate-info-gain $other $p) (* $p 0.3))

;; =============================================================================
;; Anti-goal Integration
;; =============================================================================

;; Named helper for antigoal magus-fold operation
(= (antigoal-penalty-helper $antigoal $candidate $context $acc)
   (* $acc (apply-single-antigoal $antigoal $context $candidate)))

;; Calculate anti-goal penalties
(= (calculate-antigoal-penalty $candidate $context Nil) 1.0)
(= (calculate-antigoal-penalty $candidate $context (Cons $antigoal $tail))
   (* (apply-single-antigoal $antigoal $context $candidate)
      (calculate-antigoal-penalty $candidate $context $tail)))

;; Apply single anti-goal
(= (apply-single-antigoal (anti-goal $name Hard $fn) $context $candidate)
   ($fn (scoring-to-antigoal-context $context) $candidate))
(= (apply-single-antigoal (anti-goal $name Soft $fn) $context $candidate)
   ($fn (scoring-to-antigoal-context $context) $candidate))

;; Convert scoring context to anti-goal context
(= (scoring-to-antigoal-context (scoring-context $goals $mods $time))
   (context $goals $time))

;; =============================================================================
;; Overgoal Calculation (Measurability-Weighted Goal Correlations)
;; =============================================================================

;; Helper: Extract goal name from Goal
(= (get-goal-name (goal $name $priority $weight)) $name)

;; Calculate overgoal score for a specific goal based on weighted correlations
;; This represents how well the goal fits with the overall goal set
;; Formula: Average of measurability-weighted correlations with other active goals
;;
;; Integrates M2 measurability and correlation data
;; The weighted correlation formula is: base_correlation × sqrt(measurability1 × measurability2)
;;
;; Usage: Can be called to assess goal coherence/synergy in the current goal set
;; Higher overgoal scores indicate goals that align well with other goals
(= (calculate-overgoal-score $target-goal Nil) 0.0)
(= (calculate-overgoal-score $target-goal (Cons $goal $rest))
   (let* (;; Extract goal names
          ($target-name (get-goal-name $target-goal))
          ($other-name (get-goal-name $goal))
          ;; Get M2 data - base correlation between goals
          ($base-corr (get-correlation $target-name $other-name))
          ;; Get M2 measurabilities
          ($meas1 (get-measurability $target-name))
          ($meas2 (get-measurability $other-name))
          ;; Calculate weighted correlation: base_corr × sqrt(meas1 × meas2)
          ($weighted (get-weighted-correlation-for-overgoal
                       $target-name $other-name $base-corr $meas1 $meas2))
          ;; Recursively calculate for remaining goals
          ($rest-sum (calculate-overgoal-score $target-goal $rest))
          ;; Count total goals for averaging
          ($count (+ 1 (magus-length $rest))))
     ;; Return average weighted correlation
     (if (> $count 0)
         (/ (+ $weighted $rest-sum) $count)
         0.0)))

;; Calculate overgoal adjustment for a goal within its scoring context
;; Applies a bonus based on how well the goal aligns with other active goals
;; Bonus formula: 0.3 × overgoal_score (overgoal_score is 0-1 range)
(= (calculate-overgoal-adjustment $goal (scoring-context $goals $mods $time))
   (let* (;; Get overgoal score (average weighted correlation with other goals)
          ($overgoal-score (calculate-overgoal-score $goal $goals))
          ;; Apply bonus: 0.0 to 0.3 based on overgoal score
          ($bonus (* 0.3 $overgoal-score)))
     $bonus))

;; Calculate overall goal set coherence using overgoal scores
;; Returns average overgoal score across all goals
(= (calculate-goalset-coherence Nil) 0.0)
(= (calculate-goalset-coherence (Cons $goal $rest))
   (let* (($count (+ 1 (magus-length $rest)))
          ($total (+ (calculate-overgoal-score $goal $rest)
                     (* $count (calculate-goalset-coherence $rest)))))
     (if (> $count 0)
         (/ $total $count)
         0.0)))

;; =============================================================================
;; Complete Scoring Pipeline v2
;; =============================================================================

;; Main scoring function with full integration
(= (score-decision-v2 $candidate $considerations $discouragements
                     $metagoals $antigoals $context)
   (let* (;; Calculate base utility
          ($base (calculate-base-utility $considerations $discouragements $context))
          ;; Calculate metagoal adjustments
          ($metagoal-adj (if (is-goal-candidate $candidate)
                            (calculate-metagoal-adjustment-v2
                              (extract-goal $candidate) $context $metagoals)
                            0))
          ;; Calculate overgoal adjustment (goal set coherence)
          ($overgoal-adj (if (is-goal-candidate $candidate)
                            (calculate-overgoal-adjustment
                              (extract-goal $candidate) $context)
                            0))
          ;; Calculate anti-goal penalties (multiplicative)
          ($antigoal-factor (calculate-antigoal-penalty $candidate $context $antigoals))
          ;; Combine scores: base + metagoal + overgoal, then × antigoal
          ($adjusted (+ (+ $base $metagoal-adj) $overgoal-adj))
          ($final (* $adjusted $antigoal-factor)))
     (decision-score $base $metagoal-adj $overgoal-adj (- 1 $antigoal-factor) $final)))

;; Check if candidate is a goal
(= (is-goal-candidate (goal-candidate $g)) True)
(= (is-goal-candidate (action-candidate $a)) False)

;; Extract goal from candidate
(= (extract-goal (goal-candidate $g)) $g)

;; =============================================================================
;; Explainability and Breakdown
;; =============================================================================

;; Generate detailed score breakdown
(= (generate-score-breakdown (decision-score $base $meta $overgoal $anti $final))
   (Cons (score-component base-utility $base "Base utility from considerations/discouragements")
   (Cons (score-component metagoal-adjustment $meta "Long-term strategic value")
   (Cons (score-component overgoal-adjustment $overgoal "Goal set coherence bonus")
   (Cons (score-component antigoal-penalty $anti "Risk and constraint penalties")
   (Cons (score-component final-score $final "Combined final score")
   Nil))))))

;; Format score breakdown for logging (simplified - string ops not in minimal MeTTa)
(= (format-score-breakdown $components) $components)

;; =============================================================================
;; Configuration and Tuning
;; =============================================================================

;; Scoring weights configuration
(: ScoringWeights Type)
;; base_weight, metagoal_weight, antigoal_strength

;; Default weights
(= (default-scoring-weights)
   (scoring-weights 1.0 0.3 1.0))

;; Apply custom weights to scoring
(= (score-with-weights $candidate $cons $dis $meta $anti $context
                      (scoring-weights $bw $mw $aw))
   (let* (($base (* $bw (calculate-base-utility $cons $dis $context)))
          ($meta-adj (* $mw (if (is-goal-candidate $candidate)
                               (calculate-metagoal-adjustment-v2
                                 (extract-goal $candidate) $context $meta)
                               0)))
          ($overgoal-adj (if (is-goal-candidate $candidate)
                            (calculate-overgoal-adjustment
                              (extract-goal $candidate) $context)
                            0))
          ($anti-penalty (calculate-antigoal-penalty $candidate $context $anti))
          ($anti-factor (if (== $aw 1.0)
                           $anti-penalty
                           (pow $anti-penalty $aw)))
          ($adjusted (+ (+ $base $meta-adj) $overgoal-adj))
          ($final (* $adjusted $anti-factor)))
     (decision-score $base $meta-adj $overgoal-adj (- 1 $anti-factor) $final)))

;; =============================================================================
;; Decision Ranking
;; =============================================================================

;; Rank multiple candidates by score
(= (rank-decisions $candidates $cons $dis $meta $anti $context)
   (sort-by-score
     (score-all-candidates $candidates $cons $dis $meta $anti $context)))

;; Score all candidates
(= (score-all-candidates Nil $cons $dis $meta $anti $context) Nil)
(= (score-all-candidates (Cons $cand $tail) $cons $dis $meta $anti $context)
   (Cons ($cand (score-decision-v2 $cand $cons $dis $meta $anti $context))
         (score-all-candidates $tail $cons $dis $meta $anti $context)))

;; Sort candidates by score (simple insertion sort)
(= (sort-by-score Nil) Nil)
(= (sort-by-score (Cons $head $tail))
   (insert-by-score $head (sort-by-score $tail)))

;; Insert candidate in sorted position
(= (insert-by-score $item Nil) (Cons $item Nil))
(= (insert-by-score ($c1 (decision-score $b1 $m1 $o1 $a1 $f1))
                   (Cons ($c2 (decision-score $b2 $m2 $o2 $a2 $f2)) $tail))
   (if (> $f1 $f2)
       (Cons ($c1 (decision-score $b1 $m1 $o1 $a1 $f1))
             (Cons ($c2 (decision-score $b2 $m2 $o2 $a2 $f2)) $tail))
       (Cons ($c2 (decision-score $b2 $m2 $o2 $a2 $f2))
             (insert-by-score ($c1 (decision-score $b1 $m1 $o1 $a1 $f1)) $tail))))

;; =============================================================================
;; Logging and Observability
;; =============================================================================

;; Log space for decision history
!(bind! &decision-log (new-space))

;; Log a decision with breakdown
(= (log-decision $candidate $score $timestamp)
   (add-atom &decision-log
     (decision-event $candidate $score $timestamp)))

;; Query decision history
(= (get-decision-history $start-time $end-time)
   (match &decision-log
     (decision-event $c $s $t)
     (if (and (>= $t $start-time) (<= $t $end-time))
         ($c $s $t)
         Empty)))

;; =============================================================================
;; Module Export
;; =============================================================================

;; Export main functions for use by other modules
(= (scoring-v2-module-exports)
   (list
     score-decision-v2
     score-with-weights
     rank-decisions
     generate-score-breakdown
     format-score-breakdown
     log-decision
     default-scoring-weights))