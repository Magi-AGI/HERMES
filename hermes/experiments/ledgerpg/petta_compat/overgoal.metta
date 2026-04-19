;; MAGUS Milestone 3: Overgoal Module
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
