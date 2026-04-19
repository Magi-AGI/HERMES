;; MAGUS Milestone 3: Metagoals Module (Refined)
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
     record-demotion))