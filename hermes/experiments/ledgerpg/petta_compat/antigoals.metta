;; MAGUS Milestone 3: Anti-goals Module (Refined)
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
     ambiguity-antigoal))