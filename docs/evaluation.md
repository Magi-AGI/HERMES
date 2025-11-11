Evaluation Plan

Dimensions
- Causal fidelity & goal correlation
  - Pearson/Spearman correlation and MI between predicted attributions and observed goal changes.
  - FP/FN rates for CausalLink edges under controlled scenarios.

- Reasoning utility in MAGUS
  - Success rate uplift vs. baseline (no HERMES) on game tasks.
  - Planning/search efficiency: reduced branching depth/time to success.

- Symbolic compression
  - Graph compactness (node/edge counts) before/after motif abstraction.
  - Redundancy scores across episodes.

- Performance & scalability
  - Construction/export times for increasing episode sizes.
  - Memory footprint during ingestion and miner passes.
  - Atomspace/MORK query latencies for attribution and causal chains.

Methodology
- Datasets: example game logs (Hello Cube, Move Cube, scaled runs) with known outcomes.
- Baselines: naive frequency attribution; no temporal lag; no miner compression.
- Protocol: repeated runs with randomized seeds to evaluate stability of lags/confidences.

Targets
- ≥ 30% improvement in agent performance with HERMES graphs available.
- ≥ 25% reduction in processing/query time after optimizations and motif compression.
- ≥ 95% round‑trip fidelity on MORK persistence.

