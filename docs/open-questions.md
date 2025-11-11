Open Questions and Decisions

Resolved by Stakeholder
- Miner: assume approach similar to hyperon-miner / hyperon-miner-2.
- Persistence: use MORK repo specifics.
- PLN: no solid example yet; defer integration.
- Data: games will emit logs connecting actions → effects → satisfactions; delays may exist.

Pending Clarifications
- Canonical list of MAGUS goals/subgoals and modulators to import (from ../metta-magus/), including stable IDs and any short names.
- Default temporal parameters: horizon H and per‑goal γ, λ; initial lag priors.
- API exposure beyond MeTTa: choose between HTTP, gRPC, or message bus; expected throughput and deployment constraints.
- Target runtime environment (hardware profile) and MORK configuration to use for baselines.
- Exact AIRIS log schema/versioning and event frequencies for streaming mode.

Implementation Risks
- Lag inference accuracy on sparse/short episodes.
- Confounding actions in dense multi‑agent scenarios (need context tags/filters).
- Miner throughput on large spaces without MORK acceleration.

