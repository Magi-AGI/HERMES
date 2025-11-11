;; HERMES demo module: sample facts and simple queries
;; Organized per metta-best-practices: separate spaces for facts (&kb) and queries (&self)

!(bind! &kb (new-space))

(: CausalLink (-> Atom Atom))
(: SatisfactionDelta (-> Goal Number))
(: Attribution (-> Action Goal Number Number Number))

;; Sample facts (Hello Cube style)
!(add-atom &kb (CausalLink (pickup cubeA) (inventory added cubeA)))
!(add-atom &kb (CausalLink (place cubeA pointB) (world placed cubeA pointB)))
!(add-atom &kb (CausalLink (world placed cubeA pointB) (Satisfaction TaskCompletion)))
!(add-atom &kb (SatisfactionDelta TaskCompletion +0.4))
!(add-atom &kb (Attribution (place cubeA pointB) TaskCompletion 0 0.35 0.85))

;; Simple query utilities
(: get-causal-chain (-> Action Atom (Tuple)))
(: get-attributions (-> Goal Atom Number (Tuple)))

(= (get-causal-chain $action $ctx)
   (match &kb (CausalLink $action $effect) (tuple $effect)))

(= (get-attributions $goal $ctx $h)
   (match &kb (Attribution $a $goal $lag $w $conf) (tuple $a $lag $w $conf)))

;; Tests (requires assertEqualToResult available in environment)
!(assertEqualToResult (get-causal-chain (place cubeA pointB) &ctx)
   ((world placed cubeA pointB)))

!(assertEqualToResult (get-attributions TaskCompletion &ctx 10)
   (((place cubeA pointB) 0 0.35 0.85)))

;; Naive motif abstraction example (brick move instances)
!(add-atom &kb (CausalLink (pickup brick_1) (inventory added brick_1)))
!(add-atom &kb (CausalLink (place brick_1 tableB) (progress cube_rebuilt 0.1)))
!(add-atom &kb (CausalLink (progress cube_rebuilt 0.1) (Satisfaction ResourceTransfer)))
!(add-atom &kb (SatisfactionDelta ResourceTransfer +0.1))

!(add-atom &kb (CausalLink (pickup brick_2) (inventory added brick_2)))
!(add-atom &kb (CausalLink (place brick_2 tableB) (progress cube_rebuilt 0.2)))
!(add-atom &kb (CausalLink (progress cube_rebuilt 0.2) (Satisfaction ResourceTransfer)))
!(add-atom &kb (SatisfactionDelta ResourceTransfer +0.08))

(: get-brick-move-motifs (-> Atom (Tuple)))
(= (get-brick-move-motifs $ctx)
   (match &kb (CausalLink (place $brick tableB) $x) (tuple $brick)))

!(assertEqualToResult (get-brick-move-motifs &ctx)
   ((brick_1 brick_2)))
