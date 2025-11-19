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
 - OpenPsi-MAGUS integration work (hyperon-openpsi and related analyses) treats HERMES as a downstream causal reasoning service: initial phases focus on wiring OpenPsi into MAGUS goal management and scoring, with optional future steps where MAGUS or OpenPsi may also consult HERMES-derived causal summaries (e.g., action→goal attributions) when learning or refining rules.

Default MAGUS/HERMES integration stack
- In the MAGUS research and implementation guides, HERMES is expected to integrate with concrete Hyperon codebases rather than hypothetical components:
  - PeTTa (`hyperon reference/PeTTa/`): provides working MeTTa implementations of PLN and NARS (`lib_pln.metta`, `lib_nars.metta`) that can reason over HERMES-exported facts and motifs.
  - hyperon-experimental (`hyperon reference/hyperon-experimental/`): provides the `EventAgent` and `&event_bus`/`queue-subscription` mechanism used by MAGUS agents to publish events and traces.
- In practice, the recommended path is:
  - Use EventAgent-based agents (or their logging output) as the primary source of HERMES trace input (see `message-contracts.md`).
  - Use PeTTa’s PLN/NARS libraries as the default reasoning backends when you want to run higher-level reasoning over the causal graphs and motifs that HERMES builds, keeping the interface modular so alternative reasoners can be plugged in later.

Event-driven trade-offs and timeline
- EventAgent (from hyperon-experimental PR #852, merged March 2025) offers a mature event-driven pattern for MAGUS/HERMES integration: decoupled components communicating via an event bus, with queue-based subscriptions handled in background threads.
- Compared to direct, function-call integration, EventAgent trades slightly higher latency and implementation complexity for much better decoupling, easier testing (mocked events), and scalability as more MAGUS components are added.
- For near-term MAGUS milestones, the recommended approach is to adopt EventAgent (and its `BasicEventBus`) as the default ingestion source for HERMES, reserving direct integration only for simple or experimental setups; HERMES’ ingestion API remains generic enough to accept either.

Reasoner trade-offs (PLN vs NARS)
- MAGUS research on PLN/NARS convergence shows that under high uncertainty in term probabilities, both systems converge on a similar 'power' metric (strength or frequency × confidence), with NARS-style formulas effectively approximating this power while avoiding explicit term probability tracking.
- In early deployments where knowledge is sparse and term probabilities are poorly calibrated, it is reasonable for downstream reasoning over HERMES graphs and motifs to start with NARS-like truth value handling (via PeTTa's lib_nars.metta) and adopt PLN-heavy reasoning (lib_pln.metta) gradually as term-confidence improves, without changing HERMES' exported structures.

Testing/Examples
- Include MeTTa tests for:
  - Adding and querying CausalLink/SatisfactionDelta/Attribution.
  - Running miner with small &miner space and consuming a returned motif.
  - Ensuring motif abstraction reduces redundancy (compression ratio metric).
