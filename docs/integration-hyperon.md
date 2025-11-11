Hyperon Integrations

Pattern Miner
- References: ../../hyperon reference/hyperon-miner, ../../hyperon reference/hyperon-miner-2
- Approach:
  - Publish mined‑ready MeTTa facts into a dedicated &miner space (facts only).
  - Run frequent pattern mining with a chosen min_support per scenario.
  - Optionally run surprisingness scoring phase for causality hints.
  - Consume frequent/causal motifs to:
    - Compress graphs (replace repeated subgraphs with abstract motifs).
    - Refine temporal priors (lag distributions, attribution weights) conditioned on context.
  - Keep motif abstractions and their bindings queryable in &self (read‑only in production).

Atomspace / MeTTa
- Construct nodes and links directly in Atomspace (Action, StateDelta, Goal, Context; CausalLink, SatisfactionDelta, Attribution).
- Serialize all structures to MeTTa expressions and expose queries per metta-best-practices.
- Use separate spaces: &kb (facts), &miner (facts for mining), &self (rules/queries), &tests (test scaffolds).

MORK Persistence
- Reference: ../../hyperon reference/MORK
- Persist spaces used by HERMES (primarily &kb) and measure:
  - Load/save latency for episodes of varying sizes.
  - Query latency impacts for attribution and causal‑chain retrieval.
- Keep round‑trip fidelity target ≥ 95% for all HERMES atoms.

OpenPsi / PLN
- No solid PLN example is available yet; leave interfaces modular to connect future PLN or OpenPsi reasoning over HERMES motifs and attributions.

Testing/Examples
- Include MeTTa tests for:
  - Adding and querying CausalLink/SatisfactionDelta/Attribution.
  - Running miner with small &miner space and consuming a returned motif.
  - Ensuring motif abstraction reduces redundancy (compression ratio metric).

