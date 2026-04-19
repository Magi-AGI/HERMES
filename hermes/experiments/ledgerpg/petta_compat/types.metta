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
(: False Bool)