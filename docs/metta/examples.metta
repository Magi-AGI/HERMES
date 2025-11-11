;; HERMES example atoms and queries

(: CausalLink (-> Atom Atom))
(: SatisfactionDelta (-> Goal Number))
(: Attribution (-> Action Goal Number Number Number))

;; Simple chain
(CausalLink (press red_button) (gate open))
(CausalLink (gate open) (Satisfaction Safety))
(SatisfactionDelta Safety +0.4)
(Attribution (press red_button) Safety 1 0.35 0.82)

;; Query helpers (signatures illustrative)
(: get-attributions (-> Goal Atom Number (Tuple)))
(: get-causal-chain (-> Action Atom (Tuple)))
(: suggest-actions (-> Goal Atom Number (Tuple)))

