;; Grounded Math Functions Extension
;; Loads Python math functions (sqrt, pow, etc.) as grounded operations
;; These are needed because Hyperon 0.2.1 doesn't include them by default

;; This file should be loaded after types.metta
;; Usage: !(load math-grounded.metta)

;; The actual grounded functions are registered via Python's @register_atoms
;; See math_ext.py for the implementation

;; Type declarations for grounded math functions
(: sqrt (-> Number Number))
(: pow (-> Number Number Number))
(: abs (-> Number Number))
(: floor (-> Number Number))
(: ceil (-> Number Number))
(: sin (-> Number Number))
(: cos (-> Number Number))
(: log (-> Number Number))
(: exp (-> Number Number))
