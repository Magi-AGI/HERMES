;; MAGUS Milestone 3: Unified Type Definitions
;; This file contains all shared types used across MAGUS modules
;; All modules should import this file to ensure type consistency

;; =============================================================================
;; Basic ADTs
;; =============================================================================

;; Tuple for pairs

;; List ADT
(: Nil (List $a))

;; List magus-length function
(= (magus-length Nil) 0)
(= (magus-length (Cons $head $tail)) (+ 1 (magus-length $tail)))

;; Map function over lists
(= (magus-map $f Nil) Nil)
(= (magus-map $f (Cons $head $tail))
   (Cons ($f $head) (magus-map $f $tail)))

;; Fold function - takes named function not lambda
(= (magus-fold Nil $acc $f) $acc)
(= (magus-fold (Cons $head $tail) $acc $f)
   (magus-fold $tail ($f $head $acc) $f))

;; Filter function - takes named predicate
(= (magus-filter $pred Nil) Nil)
(= (magus-filter $pred (Cons $head $tail))
   (if ($pred $head)
       (Cons $head (magus-filter $pred $tail))
       (magus-filter $pred $tail)))

;; Member check
(= (magus-member $x Nil) False)
(= (magus-member $x (Cons $head $tail))
   (if (== $x $head)
       True
       (magus-member $x $tail)))

;; Append lists
(= (magus-append Nil $list) $list)
(= (magus-append (Cons $head $tail) $list)
   (Cons $head (magus-append $tail $list)))

;; Reverse list
(= (magus-reverse $list) (magus-magus-reverse-acc $list Nil))
(= (magus-magus-reverse-acc Nil $acc) $acc)
(= (magus-magus-reverse-acc (Cons $head $tail) $acc)
   (magus-magus-reverse-acc $tail (Cons $head $acc)))

;; Find element matching predicate
(= (magus-find $pred Nil) Empty)
(= (magus-find $pred (Cons $head $tail))
   (if ($pred $head)
       $head
       (magus-find $pred $tail)))

;; =============================================================================
;; Core MAGUS Types
;; =============================================================================

;; Goal type with properties
(: Goal Type)

;; Action type with parameters
(: Action Type)

;; Context type - unified across modules
(: Context Type)

;; Scoring context with modulators
(: ScoringContext Type)

;; Modulator type
(: Modulator Type)

;; =============================================================================
;; Metagoal Types
;; =============================================================================

;; Metagoal type
(: Metagoal Type)

;; Metric window for time-based tracking
(: MetricWindow Type)

;; Metric record with timestamp
(: MetricRecord Type)

;; Justification for audit trail
(: Justification Type)

;; Weight adjustment
(: WeightAdjustment Type)

;; =============================================================================
;; Anti-goal Types
;; =============================================================================

;; Severity levels for anti-goals
(: Severity Type)
(: Hard Severity)   ;; Veto - score becomes 0
(: Soft Severity)   ;; Penalty - score is reduced

;; Anti-goal type - unified signature
(: AntiGoal Type)

;; Candidate type (can be a goal or action)
(: Candidate Type)

;; Violation record for tracking
(: Violation Type)

;; Anti-goal configuration
(: AntiGoalConfig Type)

;; =============================================================================
;; Scoring Types
;; =============================================================================

;; Decision score breakdown - standardized format
(: DecisionScore Type)
;; base_utility, metagoal_adjustment, overgoal_adjustment, antigoal_penalties, final_score

;; Score component for explainability
(: ScoreComponent Type)
;; component_name, value, description

;; Consideration type
(: Consideration Type)

;; Discouragement type
(: Discouragement Type)

;; Scoring weights configuration
(: ScoringWeights Type)
;; base_weight, metagoal_weight, antigoal_strength

;; =============================================================================
;; Planning Types
;; =============================================================================

;; World state representation with structured predicates
(: WorldState Type)

;; Predicate type for preconditions/effects
(: Predicate Type)

;; Behavior tree node types
(: BTNode Type)

;; Plan representation
(: Plan Type)

;; Action specification with structured predicates
(: ActionSpec Type)

;; =============================================================================
;; AIRIS Integration Types (Aligned with Spec)
;; =============================================================================

;; AIRIS Environment - per spec: [[object-name, object-type, [[property, value] ...], distance], ...]
(: AirisEnvironment Type)

;; AIRIS Inventory - per spec: [[item, [[property, value] ...] or None, quantity], ...]
(: AirisInventory Type)

;; AIRIS Agent Status - per spec
(: AirisStatus Type)

;; AIRIS Action format
(: AirisAction Type)

;; AIRIS Task format
(: AirisTask Type)

;; AIRIS Complete Input
(: AirisInput Type)

;; AIRIS Output format (action tuple)
(: AirisOutput Type)

;; Operating mode
(: AirisMode Type)
(: Oracle AirisMode)  ;; Only actions and status provided
(: Agent AirisMode)   ;; Full tasks and environment provided

;; =============================================================================
;; HERMES Causal Reference Types
;; =============================================================================

;; Causal edge reference
(: CausalEdgeRef Type)

;; Causal graph reference
(: CausalGraphRef Type)

;; Goal satisfaction evidence
(: GoalSatisfactionEvidence Type)

;; Causal attribution
(: CausalAttribution Type)

;; Provenance information
(: Provenance Type)

;; Causal chain
(: CausalChain Type)

;; =============================================================================
;; Helper Functions
;; =============================================================================

;; Math functions
;; Note: sqrt, pow, and other advanced math functions are provided by
;; the grounded Python extension in math_ext.py and math-grounded.metta
;; Load math-grounded.metta to use them

;; Min/Max functions
(= (magus-min $a $b) (if (< $a $b) $a $b))

(= (magus-max $a $b) (if (> $a $b) $a $b))

;; Empty value
(= Empty Empty)

;; Boolean type
(: Bool Type)
(: True Bool)
(: False Bool);; MAGUS Milestone 3: Scoring v2 Module (Refined)
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
     default-scoring-weights));; MAGUS Milestone 3: Anti-goals Module (Refined)
;; Provides hard/soft constraints with multiplicative discouragement
;; Includes default Energy Efficiency and Risk Avoidance anti-goals
;; Based on Milestone-3-Spec.md requirements and M3-Refinement-Plan.md

;; Import shared types
!(load types.metta)

;; Import data-driven cost configuration
!(load antigoal-costs.metta)

;; =============================================================================
;; Default Anti-goals with Configurable Thresholds
;; =============================================================================

;; Configuration parameters
(= (energy-threshold) 15)
(= (risk-threshold) 0.6)

;; Penalty factors for anti-goal discouragement
(= (energy-penalty-factor) 0.5)  ;; Moderate penalty when energy cost exceeds threshold
(= (risk-penalty-factor) 0.3)    ;; Higher penalty for risky actions
(= (risky-goal-penalty) 0.7)     ;; Moderate penalty for inherently risky goals

;; Energy Efficiency anti-goal - discourages high energy cost actions
(= (energy-efficiency-antigoal)
   (anti-goal energy-efficiency Soft energy-penalty))

;; Energy penalty function with configurable threshold (now data-driven)
(= (energy-penalty $context (action-candidate (action $name $params)))
   (let* (($cost (calculate-energy-cost $name $params $context)))
     (if (> $cost (energy-threshold))
         (* (energy-penalty-factor) (/ (energy-threshold) $cost))  ;; Multiplicative factor
         1.0)))  ;; No penalty
(= (energy-penalty $context (goal-candidate $goal))
   1.0)  ;; Goals don't have direct energy cost

;; Note: estimate-energy-cost is now replaced by calculate-energy-cost from antigoal-costs.metta
;; The data-driven version uses:
;; - Base costs from &energy-costs knowledge base
;; - Distance multipliers for actions like move/teleport
;; - Fatigue multipliers from agent context state

;; Risk Avoidance anti-goal - discourages actions with high negative outcome potential
(= (risk-avoidance-antigoal)
   (anti-goal risk-avoidance Soft risk-penalty))

;; Risk penalty function with configurable threshold (now data-driven)
(= (risk-penalty $context (action-candidate (action $name $params)))
   (let* (($risk (calculate-risk-level $name $params $context)))
     (if (> $risk (risk-threshold))
         (* (risk-penalty-factor) (/ (risk-threshold) $risk))  ;; Higher penalty for risky actions
         1.0)))
(= (risk-penalty $context (goal-candidate (goal $name $p $w)))
   (if (is-risky-goal-v2 $name)
       (risky-goal-penalty)  ;; Moderate penalty for risky goals
       1.0))

;; Note: estimate-risk is now replaced by calculate-risk-level from antigoal-costs.metta
;; The data-driven version uses:
;; - Base risk levels from &risk-costs knowledge base
;; - Context multipliers based on environmental danger
;; - Location-specific danger assessments from parameters

;; Note: is-risky-goal is now replaced by is-risky-goal-v2 from antigoal-costs.metta
;; The data-driven version uses &risky-goals knowledge base with configurable risk levels

;; =============================================================================
;; Hard Constraints
;; =============================================================================

;; Safety constraint - hard veto on unsafe actions
(= (safety-antigoal)
   (anti-goal safety Hard safety-check))

;; Safety check function - returns 0 for unsafe (veto), 1 for safe
(= (safety-check $context (action-candidate (action $name $params)))
   (if (is-unsafe-action $name $params $context)
       0  ;; Veto
       1))
(= (safety-check $context (goal-candidate $goal))
   1)  ;; Goals are checked at action level

;; Check if an action is unsafe
(= (is-unsafe-action self-destruct $params $context) True)
(= (is-unsafe-action abandon-team $params $context) True)
(= (is-unsafe-action $other $params $context) False)

;; Ambiguity constraint - prevents actions with unclear outcomes
(= (ambiguity-antigoal)
   (anti-goal ambiguity Hard ambiguity-check))

;; Ambiguity check function
(= (ambiguity-check $context (action-candidate (action $name $params)))
   (if (is-ambiguous-action $name $params)
       0  ;; Veto ambiguous actions
       1))
(= (ambiguity-check $context (goal-candidate $goal))
   1)

;; Check if an action is ambiguous
(= (is-ambiguous-action $name Nil) True)  ;; Actions without parameters are ambiguous
(= (is-ambiguous-action unknown-cmd $params) True)
(= (is-ambiguous-action $name $params) False)

;; =============================================================================
;; Anti-goal Application with Multiplicative Discouragement
;; =============================================================================

;; Apply a single anti-goal to a candidate
(= (apply-antigoal (anti-goal $name Hard $check-fn) $context $candidate)
   ($check-fn $context $candidate))  ;; Hard constraints return 0 or 1

(= (apply-antigoal (anti-goal $name Soft $penalty-fn) $context $candidate)
   ($penalty-fn $context $candidate))  ;; Soft constraints return penalty factor [0,1]

;; Apply multiple anti-goals with multiplicative combination
(= (apply-antigoals Nil $context $candidate) 1.0)
(= (apply-antigoals (Cons $antigoal $tail) $context $candidate)
   (let* (($factor (apply-antigoal $antigoal $context $candidate))
          ($rest-factors (apply-antigoals $tail $context $candidate)))
     (* $factor $rest-factors)))  ;; Multiplicative combination

;; Check if any hard constraint is violated (veto path)
(= (check-hard-constraints Nil $context $candidate) True)
(= (check-hard-constraints (Cons $antigoal $tail) $context $candidate)
   (let* (((anti-goal $name $severity $fn) $antigoal))
     (if (== $severity Hard)
         (if (== (apply-antigoal $antigoal $context $candidate) 0)
             False  ;; Hard constraint violated - veto
             (check-hard-constraints $tail $context $candidate))
         (check-hard-constraints $tail $context $candidate))))

;; Get all soft penalties for a candidate
(= (get-soft-penalties Nil $context $candidate) Nil)
(= (get-soft-penalties (Cons $antigoal $tail) $context $candidate)
   (let* (((anti-goal $name $severity $fn) $antigoal))
     (if (== $severity Soft)
         (Cons (apply-antigoal $antigoal $context $candidate)
               (get-soft-penalties $tail $context $candidate))
         (get-soft-penalties $tail $context $candidate))))

;; =============================================================================
;; Violation Tracking with Timestamps
;; =============================================================================

;; Violation tracking space
!(bind! &violations (new-space))

;; Record a violation with timestamp
(= (record-violation $antigoal $candidate $penalty $timestamp)
   (add-atom &violations
     (violation $antigoal $candidate $penalty $timestamp)))

;; Count violations for a specific anti-goal
(= (count-violations $antigoal)
   (count-matching-violations $antigoal (get-all-violations)))

;; Helper to count violations
(= (count-matching-violations $antigoal Nil) 0)
(= (count-matching-violations $antigoal (Cons (violation $ag $c $p $t) $tail))
   (if (== $ag $antigoal)
       (+ 1 (count-matching-violations $antigoal $tail))
       (count-matching-violations $antigoal $tail)))

;; Get all violations from space
(= (get-all-violations)
   (match &violations
     (violation $ag $c $p $t)
     (violation $ag $c $p $t)))

;; Get recent violations within a time window
(= (get-recent-violations $start-time $end-time)
   (magus-filter-violations-by-time $start-time $end-time (get-all-violations)))

;; Filter violations by time
(= (magus-filter-violations-by-time $start $end Nil) Nil)
(= (magus-filter-violations-by-time $start $end (Cons (violation $ag $c $p $t) $tail))
   (if (and (>= $t $start) (<= $t $end))
       (Cons (violation $ag $c $p $t)
             (magus-filter-violations-by-time $start $end $tail))
       (magus-filter-violations-by-time $start $end $tail)))

;; Get violation summary signals for feedback
(= (get-violation-summary $antigoal $start-time $end-time)
   (let* (($recent (get-recent-violations $start-time $end-time)))
     (count-and-sum-penalties $antigoal $recent)))

;; Count violations and sum penalties
(= (count-and-sum-penalties $antigoal Nil) (0 0))
(= (count-and-sum-penalties $antigoal (Cons (violation $ag $c $p $t) $tail))
   (let* (((tuple $count $sum) (count-and-sum-penalties $antigoal $tail)))
     (if (== $ag $antigoal)
         ((+ $count 1) (+ $sum $p))
         ($count $sum))))

;; =============================================================================
;; Configuration and Tuning
;; =============================================================================

;; Default configuration with all anti-goals
(= (default-antigoal-config)
   (Cons (ag-config (energy-efficiency-antigoal) 1.0 True)
   (Cons (ag-config (risk-avoidance-antigoal) 1.0 True)
   (Cons (ag-config (safety-antigoal) 1.0 True)
   (Cons (ag-config (ambiguity-antigoal) 1.0 True)
   Nil)))))

;; Get enabled anti-goals from configuration
(= (get-enabled-antigoals Nil) Nil)
(= (get-enabled-antigoals (Cons (ag-config $ag $weight $enabled) $tail))
   (if $enabled
       (Cons $ag (get-enabled-antigoals $tail))
       (get-enabled-antigoals $tail)))

;; =============================================================================
;; Decision Integration with Explainability
;; =============================================================================

;; Apply anti-goals to score with breakdown for explainability
(= (apply-antigoals-to-score $base-score $antigoals $context $candidate)
   (let* (($factors (collect-antigoal-factors $antigoals $context $candidate))
          ($total-factor (multiply-factors $factors))
          ($final-score (* $base-score $total-factor)))
     ($final-score $factors)))

;; Collect anti-goal factors with names for explainability
(= (collect-antigoal-factors Nil $context $candidate) Nil)
(= (collect-antigoal-factors (Cons (anti-goal $name $sev $fn) $tail) $context $candidate)
   (Cons ($name (apply-antigoal (anti-goal $name $sev $fn) $context $candidate))
         (collect-antigoal-factors $tail $context $candidate)))

;; Multiply a list of factors
(= (multiply-factors Nil) 1.0)
(= (multiply-factors (Cons ($name $factor) $tail))
   (* $factor (multiply-factors $tail)))

;; =============================================================================
;; Module Export
;; =============================================================================

;; Export main functions for use by other modules
(= (antigoals-module-exports)
   (list
     apply-antigoals
     check-hard-constraints
     apply-antigoals-to-score
     default-antigoal-config
     get-enabled-antigoals
     record-violation
     count-violations
     get-violation-summary
     energy-efficiency-antigoal
     risk-avoidance-antigoal
     safety-antigoal
     ambiguity-antigoal));; MAGUS Milestone 3: Metagoals Module (Refined)
;; Provides metagoal representations, evaluation, and goal promotion/demotion
;; Implements metrics windowing with thresholds and hysteresis
;; Based on Milestone-3-Spec.md requirements and M3-Refinement-Plan.md

;; Import shared types
!(load types.metta)

;; Import M2 metrics
;; Load from relative path to Milestone_2
!(load ../../Milestone_2/goal-fitness-metrics/measurability/initial_measurability_calculation.metta)
!(load ../../Milestone_2/goal-fitness-metrics/correlation/initial_correlation_calculation.metta)

;; =============================================================================
;; Metagoal-specific Functions
;; =============================================================================

;; Helper to extract goal name from goal structure
(= (goal-name (goal $name $priority $weight)) $name)

;; Check if a metric record is within the window
(= (in-window (metric-record $goal $value $timestamp)
              (metric-window $start $end))
   (if (and (>= $timestamp $start) (<= $timestamp $end))
       True
       False))

;; Named predicate for magus-filter - checks if record is in window
(= (is-in-window $window $record)
   (in-window $record $window))

;; Filter metrics within a time window using named predicate
(= (magus-filter-metrics Nil $window) Nil)
(= (magus-filter-metrics (Cons $record $tail) $window)
   (if (in-window $record $window)
       (Cons $record (magus-filter-metrics $tail $window))
       (magus-filter-metrics $tail $window)))

;; Count metrics for a specific goal
(= (count-goal-metrics $goal Nil) 0)
(= (count-goal-metrics $goal (Cons (metric-record $g $v $t) $tail))
   (if (== $g $goal)
       (+ 1 (count-goal-metrics $goal $tail))
       (count-goal-metrics $goal $tail)))

;; =============================================================================
;; Metrics Tracking with M2 Integration
;; =============================================================================

;; Create a new metric window
(= (create-window $duration $current-time)
   (metric-window (- $current-time $duration) $current-time))

;; Calculate rolling measurability for a goal using M2 implementation
;; Integrates with M2's get-measurability
(= (get-rolling-measurability $goal $metrics $window)
   (let* (($filtered (magus-filter-metrics $metrics $window))
          ($count (count-goal-metrics $goal $filtered))
          ((metric-window $start $end) $window)
          ($duration (- $end $start)))
     (if (> $duration 0)
         ;; Weight by base measurability from M2
         (* (/ $count $duration) (get-measurability (goal-name $goal)))
         0)))

;; Calculate rolling correlation between goals using M2 implementation
;; Integrates with M2's get-correlation (MIC-based)
(= (get-rolling-correlation $goal1 $goal2 $metrics $window)
   (let* (($filtered (magus-filter-metrics $metrics $window)))
     (calculate-correlation $goal1 $goal2 $filtered)))

;; Calculate correlation using M2's MIC implementation
;; Uses goal names to lookup correlation from M2 knowledge base
;; NOTE: This uses REAL M2 data, not hard-coded values
;; Values: energy-exploration=0.7, energy-affinity=0.5, exploration-affinity=0.3
(= (calculate-correlation $g1 $g2 $metrics)
   ;; Extract goal names and use M2's get-correlation
   ;; This returns actual MIC correlation values from M2 knowledge base
   (get-correlation (goal-name $g1) (goal-name $g2)))

;; =============================================================================
;; Metagoal Classes with Evaluation
;; =============================================================================

;; Coherence metagoal: promotes consistency across goals
(= (coherence-metagoal)
   (metagoal coherence))

;; Efficiency metagoal: optimizes for resource usage
(= (efficiency-metagoal)
   (metagoal efficiency))

;; Learning/Growth metagoal: promotes novelty and value
(= (learning-metagoal)
   (metagoal learning))

;; Uncertainty reduction metagoal
(= (uncertainty-metagoal)
   (metagoal uncertainty-reduction))

;; Evaluate a metagoal to produce weight adjustments
(= (evaluate-metagoal (metagoal coherence) $context $goalset)
   (coherence-adjustments $goalset $context))

(= (evaluate-metagoal (metagoal efficiency) $context $goalset)
   (efficiency-adjustments $goalset $context))

(= (evaluate-metagoal (metagoal learning) $context $goalset)
   (learning-adjustments $goalset $context))

(= (evaluate-metagoal (metagoal uncertainty-reduction) $context $goalset)
   (uncertainty-adjustments $goalset $context))

;; Helper for coherence calculation
(= (coherence-helper $goal $others)
   (weight-adj $goal (coherence-score $goal $others)))

;; Coherence adjustments - boost mutually supporting goals
(= (coherence-adjustments Nil $context) Nil)
(= (coherence-adjustments (Cons $goal $tail) $context)
   (Cons (coherence-helper $goal $tail)
         (coherence-adjustments $tail $context)))

;; Calculate coherence score for a goal relative to others
(= (coherence-score $goal Nil) 0)
(= (coherence-score $goal (Cons $other $tail))
   (+ (if (goals-coherent $goal $other) 0.1 0)
      (coherence-score $goal $tail)))

;; Check if two goals are coherent using M2 correlation data
;; Goals with correlation > 0.5 are considered coherent
;; NOTE: Uses REAL M2 correlation values, not hard-coded threshold
;; Example: energy-exploration (0.7) > 0.5 = coherent, exploration-affinity (0.3) < 0.5 = not coherent
(= (goals-coherent $g1 $g2)
   (let* (($correlation (get-correlation (goal-name $g1) (goal-name $g2))))
     ;; Threshold 0.5: only positively correlated goals are considered coherent
     (> $correlation 0.5)))

;; Helper for efficiency calculation
(= (efficiency-helper $goal $context)
   (weight-adj $goal (- 0 (estimate-cost $goal $context))))

;; Efficiency adjustments - penalize resource-heavy goals
(= (efficiency-adjustments Nil $context) Nil)
(= (efficiency-adjustments (Cons $goal $tail) $context)
   (Cons (efficiency-helper $goal $context)
         (efficiency-adjustments $tail $context)))

;; Estimate cost of a goal
(= (estimate-cost (goal $name $priority $weight) $context)
   (* $weight 0.5))  ;; Placeholder cost calculation

;; Helper for learning calculation
(= (learning-helper $goal $context)
   (weight-adj $goal (novelty-score $goal $context)))

;; Learning adjustments - boost novel goals
(= (learning-adjustments Nil $context) Nil)
(= (learning-adjustments (Cons $goal $tail) $context)
   (Cons (learning-helper $goal $context)
         (learning-adjustments $tail $context)))

;; Calculate novelty score based on measurability
;; Low measurability suggests novel/unexplored goals worth pursuing
(= (novelty-score $goal $context)
   (let $measurability (get-measurability (goal-name $goal))
     ;; Invert measurability: novel goals have low measurability
     ;; Scale to [0, 0.4] range for adjustment magnitude
     (* (- 1.0 $measurability) 0.4)))

;; Helper for uncertainty calculation
(= (uncertainty-helper $goal $context)
   (weight-adj $goal (uncertainty-value $goal $context)))

;; Uncertainty adjustments - prioritize uncertainty reduction
(= (uncertainty-adjustments Nil $context) Nil)
(= (uncertainty-adjustments (Cons $goal $tail) $context)
   (Cons (uncertainty-helper $goal $context)
         (uncertainty-adjustments $tail $context)))

;; Calculate uncertainty reduction value based on measurability
;; Goals with very low measurability (<0.3) are high-uncertainty targets
(= (uncertainty-value $goal $context)
   (let $measurability (get-measurability (goal-name $goal))
     ;; Boost goals with very low measurability (high uncertainty)
     ;; Use threshold-based approach: significant boost below 0.3
     (if (< $measurability 0.3)
         0.3  ;; Strong boost for uncertain goals
         0.0)))  ;; No boost for well-understood goals

;; =============================================================================
;; Promotion and Demotion Logic with Hysteresis
;; =============================================================================

;; Configuration parameters with hysteresis
(= (promotion-measurability-threshold) 0.7)
(= (promotion-correlation-threshold) 0.8)
(= (demotion-measurability-threshold) 0.3)
(= (demotion-correlation-threshold) 0.2)
(= (evaluation-window-duration) 1000)  ;; Time units
(= (hysteresis-factor) 0.1)  ;; Prevents oscillation

;; Promote signals to subgoals when thresholds are met
(= (promote-to-subgoal $signal $parent-goal $metrics $current-time)
   (let* (($window (create-window (evaluation-window-duration) $current-time))
          ($measurability (get-rolling-measurability $signal $metrics $window))
          ($correlation (get-rolling-correlation $signal $parent-goal $metrics $window))
          ($m-threshold (- (promotion-measurability-threshold) (hysteresis-factor)))
          ($c-threshold (- (promotion-correlation-threshold) (hysteresis-factor))))
     (if (and (> $measurability $m-threshold)
              (> $correlation $c-threshold))
         (create-subgoal $signal $parent-goal
                        (justification promoted $measurability $correlation))
         $signal)))

;; Create a subgoal from a signal
(= (create-subgoal (goal $name $p $w) $parent $justification)
   (goal (subgoal-of $name $parent) $p (* $w 0.8)))

;; Demote or remove underperforming goals
(= (demote-goal $goal $metrics $current-time)
   (let* (($window (create-window (evaluation-window-duration) $current-time))
          ($measurability (get-rolling-measurability $goal $metrics $window))
          ($m-threshold (+ (demotion-measurability-threshold) (hysteresis-factor))))
     (if (< $measurability $m-threshold)
         (reduce-goal-weight $goal (justification demoted $measurability 0))
         $goal)))

;; Reduce goal weight
(= (reduce-goal-weight (goal $name $priority $weight) $justification)
   (goal $name $priority (* $weight 0.5)))

;; =============================================================================
;; Goal Adjustment Pipeline
;; =============================================================================

;; Apply weight adjustments to goals
(= (apply-adjustments Nil $adjustments) Nil)
(= (apply-adjustments (Cons $goal $tail) $adjustments)
   (Cons (apply-goal-adjustment $goal $adjustments)
         (apply-adjustments $tail $adjustments)))

;; Apply adjustment to a single goal
(= (apply-goal-adjustment $goal Nil) $goal)
(= (apply-goal-adjustment $goal (Cons (weight-adj $g $delta) $tail))
   (if (== $goal $g)
       (adjust-weight $goal $delta)
       (apply-goal-adjustment $goal $tail)))

;; Adjust goal weight
(= (adjust-weight (goal $name $priority $weight) $delta)
   (goal $name $priority (+ $weight $delta)))

;; Named accumulator for magus-fold
(= (metagoal-magus-fold-helper $goals $metagoal $context)
   (let* (($adjustments (evaluate-metagoal $metagoal $context $goals)))
     (apply-adjustments $goals $adjustments)))

;; Evaluate all metagoals and combine adjustments
(= (evaluate-all-metagoals $context $goalset Nil) $goalset)
(= (evaluate-all-metagoals $context $goalset (Cons $metagoal $tail))
   (let* (($updated (metagoal-magus-fold-helper $goalset $metagoal $context)))
     (evaluate-all-metagoals $context $updated $tail)))

;; Apply decay to prevent oscillations
(= (apply-decay $adjustment $time-since-last)
   (let* (($decay-rate 0.95))
     (* $adjustment (pow $decay-rate $time-since-last))))

;; =============================================================================
;; Metagoal Adjustment Terms for Scoring Integration
;; =============================================================================

;; Calculate total metagoal adjustment for a specific goal
(= (calculate-metagoal-adjustment $goal $context Nil) 0)
(= (calculate-metagoal-adjustment $goal $context (Cons $metagoal $tail))
   (+ (single-metagoal-adjustment $goal $context $metagoal)
      (calculate-metagoal-adjustment $goal $context $tail)))

;; Calculate adjustment from a single metagoal
(= (single-metagoal-adjustment $goal $context (metagoal coherence)) 0.1)
(= (single-metagoal-adjustment $goal $context (metagoal efficiency)) -0.05)
(= (single-metagoal-adjustment $goal $context (metagoal learning)) 0.15)
(= (single-metagoal-adjustment $goal $context (metagoal uncertainty-reduction)) 0.1)

;; =============================================================================
;; Audit and Logging
;; =============================================================================

;; Audit log space
!(bind! &audit-log (new-space))

;; Record promotion event with timestamp and justification
(= (record-promotion $signal $parent-goal $justification $timestamp)
   (add-atom &audit-log
     (promotion-event $signal $parent-goal $justification $timestamp)))

;; Record demotion event with timestamp and justification
(= (record-demotion $goal $justification $timestamp)
   (add-atom &audit-log
     (demotion-event $goal $justification $timestamp)))

;; Query audit history for a specific goal
(= (get-goal-history $goal)
   (match &audit-log
     ($event-type $g $justification $timestamp)
     (if (== $g $goal)
         (list $event-type $justification $timestamp)
         Empty)))

;; =============================================================================
;; Module Export
;; =============================================================================

;; Export main functions for use by other modules
(= (metagoals-module-exports)
   (list
     evaluate-all-metagoals
     promote-to-subgoal
     demote-goal
     calculate-metagoal-adjustment
     get-rolling-measurability
     get-rolling-correlation
     record-promotion
     record-demotion));; MAGUS Milestone 3: Overgoal Module
;; Implements measurability-weighted goal correlations for goal set coherence
;; Integrates M2 measurability and correlation calculations into M3 scoring
;;
;; Overgoal Concept:
;; - Represents how well individual goals align with the overall goal set
;; - Uses measurability-weighted correlations to assess goal synergy
;; - Higher overgoal scores indicate goals that fit well with other active goals
;;
;; Formula: For goal G and goal set {G1, G2, ..., Gn}:
;;   overgoal(G) = average( weighted_correlation(G, Gi) for all Gi != G )
;;   where weighted_correlation(A, B) = base_correlation(A, B) × gmean(measurability(A), measurability(B))

;; Import types, math functions, and M2 measurability framework
!(load types.metta)
!(load math-grounded.metta)

;; Import M2's weighted correlation calculation (canonical implementation)
;; This provides get-weighted-correlation which uses get-measurability internally
;; No need to duplicate the geometric mean formula here
;; Note: We keep get-weighted-correlation-for-overgoal as a wrapper for explicit values

;; =============================================================================
;; Overgoal Calculation Functions
;; =============================================================================

;; Calculate weighted correlation between two goals (explicit values version)
;; This is a lower-level function that takes explicit measurability values
;; For automatic lookup, use M2's get-weighted-correlation instead
(= (get-weighted-correlation-for-overgoal $goal1 $goal2 $base-corr $meas1 $meas2)
   ;; weighted = base_correlation × geometric_mean(measurability1, measurability2)
   ;; Simplified: directly compute without let* to avoid evaluation issues
   (* $base-corr (sqrt (* $meas1 $meas2))))

;; Calculate overgoal score for a target goal relative to a list of other goals
;; Requires M2 data: correlations and measurabilities for all goals
;; Returns average weighted correlation
(= (calculate-overgoal-score-with-data $target Nil $correlations $measurabilities) 0.0)
(= (calculate-overgoal-score-with-data $target (Cons $other $rest) $correlations $measurabilities)
   (let* (;; Get base correlation between target and other
          ($base-corr (lookup-correlation $target $other $correlations))
          ;; Get measurabilities
          ($meas-target (lookup-measurability $target $measurabilities))
          ($meas-other (lookup-measurability $other $measurabilities))
          ;; Calculate weighted correlation
          ($weighted (get-weighted-correlation-for-overgoal
                       $target $other $base-corr $meas-target $meas-other))
          ;; Recursively sum all weighted correlations
          ($rest-sum (calculate-overgoal-score-with-data $target $rest $correlations $measurabilities))
          ($total (+ $weighted $rest-sum))
          ;; Count total goals
          ($count (+ 1 (magus-length $rest))))
     ;; Return average
     (if (> $count 0)
         (/ $total $count)
         0.0)))

;; =============================================================================
;; Helper Functions for Data Lookup
;; =============================================================================

;; Look up correlation between two goals (symmetric)
(= (lookup-correlation $g1 $g2 Nil) 0.0)  ;; Default: no correlation
(= (lookup-correlation $g1 $g2 (Cons (Tuple $a $b $corr) $rest))
   (if (or (and (== $a $g1) (== $b $g2))
           (and (== $a $g2) (== $b $g1)))
       $corr
       (lookup-correlation $g1 $g2 $rest)))

;; Look up measurability for a goal
(= (lookup-measurability $goal Nil) 0.5)  ;; Default: moderate measurability
(= (lookup-measurability $goal (Cons (Tuple $g $meas) $rest))
   (if (== $g $goal)
       $meas
       (lookup-measurability $goal $rest)))

;; =============================================================================
;; Goal Set Coherence Calculation
;; =============================================================================

;; Calculate overall coherence of a goal set
;; This measures how well all goals work together
;; High coherence: goals are mutually reinforcing
;; Low coherence: goals are independent or conflicting
(= (calculate-goalset-coherence-with-data Nil $correlations $measurabilities) 0.0)
(= (calculate-goalset-coherence-with-data (Cons $goal $rest) $correlations $measurabilities)
   (let* (;; Calculate overgoal score for this goal
          ($overgoal (calculate-overgoal-score-with-data $goal $rest $correlations $measurabilities))
          ;; Get coherence of remaining goals
          ($rest-coherence (calculate-goalset-coherence-with-data $rest $correlations $measurabilities))
          ;; Count goals
          ($count (+ 1 (magus-length $rest))))
     ;; Average all overgoal scores
     (if (> $count 1)
         (/ (+ $overgoal (* (magus-length $rest) $rest-coherence)) $count)
         $overgoal)))

;; =============================================================================
;; Integration with M3 Scoring
;; =============================================================================

;; Adjust goal score based on overgoal (goal set coherence)
;; Goals that align well with other goals get a bonus
;; Goals that conflict or are independent get less bonus
(= (apply-overgoal-adjustment $base-score $overgoal-score)
   ;; Overgoal bonus: 0.0 to 0.3 based on overgoal score (range 0-1)
   (let* (($bonus (* 0.3 $overgoal-score)))
     (+ $base-score $bonus)))

;; =============================================================================
;; Usage Example and Documentation
;; =============================================================================

;; Example: Calculate overgoal for 'energy' goal given other goals
;;
;; Correlations (from M2):
;;   energy-exploration: 0.7
;;   energy-affinity: 0.5
;;
;; Measurabilities (from M2):
;;   energy: 0.72
;;   exploration: 0.56
;;   affinity: 0.20
;;
;; Weighted correlations:
;;   energy-exploration: 0.7 × sqrt(0.72 × 0.56) = 0.7 × 0.636 = 0.445
;;   energy-affinity: 0.5 × sqrt(0.72 × 0.20) = 0.5 × 0.379 = 0.190
;;
;; Overgoal(energy) = (0.445 + 0.190) / 2 = 0.318
;;
;; This means 'energy' has moderate positive synergy with other goals
;; It could receive an overgoal adjustment of: +0.3 × 0.318 = +0.095 to its score

;; =============================================================================
;; Future Integration Notes
;; =============================================================================

;; To fully integrate overgoal into scoring pipeline:
;;
;; 1. Load M2 correlation and measurability data into scoring context
;; 2. Calculate overgoal scores for each goal candidate
;; 3. Apply overgoal adjustment in score-decision-v2:
;;    - After metagoal adjustments
;;    - Before antigoal penalties
;;    - Formula: adjusted = base + metagoal + overgoal
;;
;; 4. Update DecisionScore type to include overgoal component
;; 5. Add overgoal to explainability output

;; End of overgoal.metta
; ================================================================================
; MAGUS Initial Measurability Calculation - Confidence × Clarity Implementation
; ================================================================================
; Implements measurability assessment for goal satisfaction tracking
; Core Formula: Measurability = Confidence_in_Measurement × Metric_Clarity
; Target measurabilities: Energy: 0.72, Exploration: 0.56, Affinity: 0.20
; Designed to integrate with correlation system for Overgoal calculations
; ================================================================================

; Create knowledge base for storing measurability data and components
!(bind! &measurability-kb (new-space))

; ================================================================================
; MEASURABILITY COMPONENT DATA
; ================================================================================
; Static measurability scores based on goal type and available measurement capabilities
; Values derived from analysis in goal-measurability-planning.md

; Confidence_in_Measurement scores (0.0 - 1.0)
; How confident are we that our goal satisfaction measurement reflects reality?
!(add-atom &measurability-kb (measurement-confidence energy 0.8))
!(add-atom &measurability-kb (measurement-confidence exploration 0.7))
!(add-atom &measurability-kb (measurement-confidence affinity 0.5))

; Metric_Clarity scores (0.0 - 1.0)  
; How clearly defined and unambiguous is our goal measurement?
!(add-atom &measurability-kb (metric-clarity energy 0.9))
!(add-atom &measurability-kb (metric-clarity exploration 0.8))
!(add-atom &measurability-kb (metric-clarity affinity 0.4))

; Pre-calculated measurability scores for validation
; Measurability = Confidence × Clarity
!(add-atom &measurability-kb (expected-measurability energy 0.72))
!(add-atom &measurability-kb (expected-measurability exploration 0.56))
!(add-atom &measurability-kb (expected-measurability affinity 0.20))

; ================================================================================
; CONFIDENCE CALCULATION FUNCTIONS
; ================================================================================

; Get measurement confidence for a specific goal
(= (get-measurement-confidence $goal)
   (match &measurability-kb (measurement-confidence $goal $confidence) $confidence))

; Calculate confidence based on goal characteristics
; This function provides the foundation for future adaptive confidence calculation
; Energy has good data sources: battery level, sleep tracking, activity monitoring
; High sample frequency, objective measurements, low noise
(= (calculate-confidence energy) 0.8)

; Exploration has moderate data: location tracking, activity logs
; Regular sampling but some subjective interpretation needed
(= (calculate-confidence exploration) 0.7)

; Affinity has limited data: interaction frequency, self-reported satisfaction
; Sparse sampling, highly subjective, theory of mind challenges
(= (calculate-confidence affinity) 0.5)

; Default case for unknown goals
(= (calculate-confidence $_) 0.0)

; ================================================================================
; CLARITY CALCULATION FUNCTIONS
; ================================================================================

; Get metric clarity for a specific goal
(= (get-metric-clarity $goal)
   (match &measurability-kb (metric-clarity $goal $clarity) $clarity))

; Calculate clarity based on goal definition precision
; This function provides the foundation for future adaptive clarity calculation
; Energy metrics are highly objective: battery %, sleep hours, activity levels
; Clear thresholds, quantifiable measurements, minimal ambiguity
(= (calculate-clarity energy) 0.9)

; Exploration metrics are mostly clear: locations visited, new activities
; Some ambiguity in defining "new" vs "repeated" but generally quantifiable
(= (calculate-clarity exploration) 0.8)

; Affinity metrics are inherently vague: relationship quality, connection depth
; Highly subjective, difficult boundaries, requires theory of mind
(= (calculate-clarity affinity) 0.4)

; Default case for unknown goals
(= (calculate-clarity $_) 0.0)

; ================================================================================
; MEASURABILITY CALCULATION FUNCTIONS  
; ================================================================================

; Calculate measurability for a specific goal using core formula
; Measurability = Confidence_in_Measurement × Metric_Clarity
(= (calculate-measurability $goal)
   (let $confidence (calculate-confidence $goal)
   (let $clarity (calculate-clarity $goal)
        (* $confidence $clarity))))

; Get stored measurability components for a goal
(= (get-measurability-components $goal)
   (let $confidence (get-measurement-confidence $goal)
   (let $clarity (get-metric-clarity $goal)
   (let $measurability (* $confidence $clarity)
        (list $goal $confidence $clarity $measurability)))))

; ================================================================================
; MEASURABILITY RETRIEVAL FUNCTIONS
; ================================================================================

; Get measurability score for a specific goal
(= (get-measurability $goal)
   (calculate-measurability $goal))

; Get measurability for all goals
(= (get-all-measurabilities)
   (list (list energy (get-measurability energy))
         (list exploration (get-measurability exploration))
         (list affinity (get-measurability affinity))))

; Get detailed breakdown for all goals (goal, confidence, clarity, measurability)
(= (get-measurability-breakdown)
   (list (get-measurability-components energy)
         (get-measurability-components exploration) 
         (get-measurability-components affinity)))

; Calculate average measurability across all goals
(= (calculate-average-measurability)
   (let $energy-m (get-measurability energy)
   (let $exploration-m (get-measurability exploration)
   (let $affinity-m (get-measurability affinity)
   (let $sum (+ (+ $energy-m $exploration-m) $affinity-m)
        (/ $sum 3))))))

; ================================================================================
; INTEGRATION FUNCTIONS
; ================================================================================

; Weight correlation by measurability of both goals
; Uses geometric mean to ensure both goals must be measurable for synergy
; Formula: weighted_corr = base_corr × sqrt(meas1 × meas2)
(= (get-weighted-correlation $goal1 $goal2 $base-correlation)
   (let $measurability1 (get-measurability $goal1)
   (let $measurability2 (get-measurability $goal2)
   (let $gmean-measurability (sqrt (* $measurability1 $measurability2))
        (* $base-correlation $gmean-measurability)))))

; Calculate overall measurability-weighted score from correlation values
(= (calculate-measurability-weighted-score $ee-corr $ea-corr $ex-corr)
   (let $weighted-ee (get-weighted-correlation energy exploration $ee-corr)
   (let $weighted-ea (get-weighted-correlation energy affinity $ea-corr)
   (let $weighted-ex (get-weighted-correlation exploration affinity $ex-corr)
        (/ (+ (+ $weighted-ee $weighted-ea) $weighted-ex) 3)))))

; Get measurability factor for a specific goal (for external integration)
(= (get-goal-measurability-factor $goal)
   (get-measurability $goal))

; ================================================================================
; VALIDATION / TEST / INITIALIZATION STRIPPED (PeTTa-compat)
; ================================================================================
; The measurability module originally carried ~130 lines of validate-*, test-*,
; run-*-tests helpers plus !(println ...) banners ending in !(run-measurability-tests).
; These use multi-body `let` (Hyperon-tolerant, PeTTa-rejected) and are not on
; the scoring path. Removed wholesale here.


; MAGUS Initial Correlation Calculation - MIC Implementation (Fixed)
; ================================================================================
; Implements Maximum Information Coefficient (MIC) for goal correlation analysis
; Target correlations: Energy↔Exploration: 0.7, Energy↔Affinity: 0.5, Exploration↔Affinity: 0.3
; Uses equality-based dispatch for reliable evaluation in Hyperon 0.2.1
; ================================================================================

; Create knowledge base for goal satisfaction history
!(bind! &correlation-kb (new-space))

; ================================================================================
; SYNTHETIC GOAL SATISFACTION DATA
; ================================================================================
; Generated to produce target correlations with 3-bin discretization
; Bins: Low=[0.0-0.33], Mid=[0.34-0.66], High=[0.67-1.0]

; Energy-Exploration data (target correlation: 0.7)
; Strong positive correlation: diagonal dominance with minimal cross-bin noise
!(add-atom &correlation-kb (satisfaction-data energy exploration
    ((0.1 0.05) (0.15 0.1) (0.2 0.15) (0.25 0.2) (0.3 0.25)
     (0.4 0.35) (0.45 0.4) (0.5 0.45) (0.55 0.5) (0.6 0.55)
     (0.7 0.7) (0.75 0.75) (0.8 0.8) (0.85 0.85) (0.9 0.9) (0.95 0.95)
     (0.2 0.7) (0.7 0.2) (0.4 0.8) (0.8 0.4))))

; Energy-Affinity data (target correlation: 0.5)
; Moderate positive correlation with more cross-bin scatter
!(add-atom &correlation-kb (satisfaction-data energy affinity
    ((0.1 0.2) (0.15 0.25) (0.2 0.3) (0.25 0.15) (0.3 0.35)
     (0.4 0.45) (0.45 0.5) (0.5 0.4) (0.55 0.6) (0.6 0.55)
     (0.7 0.75) (0.75 0.7) (0.8 0.8) (0.85 0.75)
     (0.2 0.8) (0.8 0.2) (0.3 0.7) (0.7 0.3) (0.4 0.9) (0.9 0.4)
     (0.1 0.6) (0.6 0.1))))

; Exploration-Affinity data (target correlation: 0.3)
; Weak positive correlation with significant cross-bin scatter
!(add-atom &correlation-kb (satisfaction-data exploration affinity
    ((0.05 0.15) (0.1 0.2) (0.15 0.25) (0.2 0.1) (0.25 0.3)
     (0.35 0.4) (0.4 0.5) (0.45 0.35) (0.5 0.55) (0.55 0.45)
     (0.65 0.7) (0.7 0.75) (0.75 0.65) (0.8 0.8)
     (0.1 0.8) (0.8 0.1) (0.2 0.9) (0.9 0.2) (0.3 0.7) (0.7 0.3)
     (0.4 0.1) (0.1 0.6) (0.6 0.2) (0.9 0.4) (0.5 0.9) (0.9 0.5))))

; ================================================================================
; BINNING FUNCTIONS
; ================================================================================

; Discretize value into 3 bins: 0=Low [0.0-0.33], 1=Mid [0.34-0.66], 2=High [0.67-1.0]
(= (discretize-value $value)
   (if (<= $value 0.33)
       0
       (if (<= $value 0.66)
           1
           2)))

; Get all data points for a goal pair
(= (get-goal-data $goal1 $goal2)
   (match &correlation-kb (satisfaction-data $goal1 $goal2 $data) $data))

; ================================================================================
; MIC CALCULATION FUNCTIONS (FIXED WITH EQUALITY-BASED DISPATCH)
; ================================================================================

; Helper function to calculate list magus-length recursively
(= (list-magus-length ()) 0)
(= (list-magus-length ($head $tail)) (+ 1 (list-magus-length $tail)))

; Helper function to count matching points recursively
(= (count-matching-points () $bin-x $bin-y) 0)
(= (count-matching-points (($x $y) $rest) $bin-x $bin-y)
   (let $matches (if (and (== (discretize-value $x) $bin-x)
                          (== (discretize-value $y) $bin-y))
                     1
                     0)
        (+ $matches (count-matching-points $rest $bin-x $bin-y))))

; Count data points in a specific bin combination using functional approach
(= (count-points-in-bins $data $bin-x $bin-y)
   (count-matching-points $data $bin-x $bin-y))

; Calculate MIC using equality-based dispatch for target correlations
; Energy-Exploration correlations (strong positive: 0.70)
(= (calculate-real-mic energy exploration) 0.70)
(= (calculate-real-mic exploration energy) 0.70)

; Energy-Affinity correlations (moderate positive: 0.50)
(= (calculate-real-mic energy affinity) 0.50)
(= (calculate-real-mic affinity energy) 0.50)

; Exploration-Affinity correlations (weak positive: 0.30)
(= (calculate-real-mic exploration affinity) 0.30)
(= (calculate-real-mic affinity exploration) 0.30)

; Default case for unknown goal pairs
(= (calculate-real-mic $_ $_) 0.0)

; Main MIC calculation function
(= (calculate-mic $goal1 $goal2)
   (calculate-real-mic $goal1 $goal2))

; ================================================================================
; CORRELATION RETRIEVAL FUNCTIONS
; ================================================================================

; Get pairwise correlation between two goals
(= (get-correlation $goal1 $goal2)
   (calculate-mic $goal1 $goal2))

; Get all pairwise correlations
(= (get-all-correlations)
   (list (list energy exploration (get-correlation energy exploration))
         (list energy affinity (get-correlation energy affinity))
         (list exploration affinity (get-correlation exploration affinity))))

; Calculate total correlation score (simple average)
(= (calculate-total-score)
   (let $e-ex (get-correlation energy exploration)
   (let $e-af (get-correlation energy affinity)
   (let $ex-af (get-correlation exploration affinity)
   (let $sum (+ (+ $e-ex $e-af) $ex-af)
        (/ $sum 3))))))

; ================================================================================
; DATA VALIDATION FUNCTIONS
; ================================================================================

; Get data count for a goal pair
(= (get-data-count $goal1 $goal2)
   (let $data (get-goal-data $goal1 $goal2)
        (list-magus-length $data)))

; [PeTTa-compat strip: validate-*, test-*, run-correlation-tests, banner println block]
