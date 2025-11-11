HERMES Specification (v0.2 Draft)
Last Updated: November 11, 2025

Purpose
- Construct, update, and serve causal hypergraphs linking agent actions to state changes and goal satisfaction over multiple time horizons, to inform MAGUS and related reasoning (e.g., OpenPsi, PLN when available).
- Provide bi‑directional translation: experiential traces → Atomspace causal structures; symbolic plans/goals → actionable guidance for AIRIS/MAGUS.
- Persist annotated graphs with confidences and temporal credit; expose via MeTTa and programmatic APIs.

System Context
HERMES operates as a bridge between experiential learning (AIRIS) and goal-directed reasoning (MAGUS):
- Input: Experience traces from AIRIS agents, MAGUS decisions, game environments
- Processing: Extract causal relationships, assign temporal credit, discover patterns
- Output: Causal attributions (Action → Goal with lag/weight/confidence) to MAGUS; refined plans to AIRIS
- Storage: Atomspace hypergraphs persisted via MORK for efficient query and retrieval

Scope
- Ingestion, event segmentation, state differencing, temporal credit assignment, causal graph construction, pattern‑miner integration, MeTTa/Atomspace serialization, MORK persistence, and MAGUS/AIRIS connectors.
- Non‑goals: building a new planner, UI visualization, or a new miner (we integrate with hyperon‑miner).

Assumptions
- Default datasets will come from example games; logs effectively connect goal‑motivated actions → action effects → goal satisfactions, but not explicitly, and delays may exist between action and eventual satisfaction.
- Pattern miner: use an approach similar to ../../hyperon reference/hyperon-miner and ../../hyperon reference/hyperon-miner-2 for discovering causal/frequent motifs.
- Persistence via MORK (../../hyperon reference/MORK). No solid PLN example yet; integration left as future work.
- MAGUS goals and modulators are defined in ../metta-magus/. Use canonical names from that repo (e.g., modulators: pleasure, arousal, dominance, focus, resolution, exteroception).

Success Criteria
- Extracts causal links (Action → ΔState → Goal) with calibrated confidences from traces with temporal delays.
- Improves MAGUS decision quality/search efficiency on game scenarios vs. baseline.
- MeTTa‑native serialization and queryability; Atomspace graph round‑trip fidelity ≥ 95%.
- Meets fidelity, utility, compression, and performance targets in Evaluation.

Key Concepts
- Experience trace: per step t: action a_t; state s_t→s_{t+1}; goal vector Δg_t (MAGUS) or curiosity (AIRIS). Context metadata (env, agent type, scenario).
- Temporal credit assignment: distribute contribution of a_t across a horizon H with goal‑specific discount γ_g and eligibility λ_g; infer likely lags τ between action and goal satisfaction from cross‑episode statistics.
- Causal graph: nodes for Action, StateDelta, Goal, Context; edges for CausalLink(Action, StateDelta), CausalLink(StateDelta, Goal), SatisfactionDelta(Goal, Δ), Attribution(Action, Goal, lag, weight, confidence).

Architecture
- Ingestion: accept AIRIS/MAGUS/game logs (batch or streaming) → canonical trace schema.
- Event segmentation: split into episodes/sub‑episodes by goal shifts or significant ΔState.
- State differencing: diff_state(s_t, s_{t+1}) → symbolic MeTTa deltas (e.g., (inventory added apple)).
- Goal deltas: measure_goal_change(goals_t, goals_{t+1}) → set of (Goal_i, Δ) filtered by threshold.
- Temporal credit: eligibility traces per goal, lag inference, confidence calibration.
- Causal constructor: create/update Atomspace subgraphs with attributes; idempotent merges; annotate metrics.
- Pattern miner: publish MeTTa facts to miner; consume frequent/causal motifs to compress graphs and refine priors (lags, weights) by context.
- Export/query: MeTTa expressions, Atomspace writer, MORK persistence; programmatic and MeTTa query APIs.
- Connectors: MAGUS adapters for goal‑centric queries; AIRIS adapter for feedback of refined plans/goal adjustments.

Data Model (MeTTa/Atomspace)
- Types (conceptual):
  - (Action $a), (StateDelta $d), (Goal $g), (Context $c), (TimeWindow $start $end)
  - (CausalLink $src $dst : (-> Atom Atom))
  - (SatisfactionDelta $g $delta : (-> Goal Number))
  - (Attribution $a $g $lag $weight $confidence : (-> Action Goal Number Number Number))
  - (ContextTag $c $k $v), (Episode $id $meta), (Step $episode $t $meta)
- Attributes: weight∈[0,1], confidence∈[0,1], lag∈Z≥0, context tags.
- Goal IDs and modulators: import canonical names from ../metta-magus/.

Message Contracts
- Trace In (JSON, batch or stream): { episode_id, t, action {name,args}, state {k:v}, goals {goal:value}, predictions?, context {k:v} }
- Graph Out (MeTTa examples):
  - (CausalLink (press red_button) (gate open))
  - (CausalLink (gate open) (Satisfaction Safety))
  - (SatisfactionDelta Safety +0.4)
  - (Attribution (press red_button) Safety 1 0.35 0.82)

Algorithms

Causal Graph Construction (per timestep t):
1. State Differencing: Δs_t = diff_state(s_t, s_{t+1}) → symbolic StateDelta atoms
2. Goal Delta Extraction: Δg_t = measure_goal_change(goals_t, goals_{t+1}) for all MAGUS goals
3. Action→State Links: Create CausalLink(a_t, Δs_t) with state confidence
4. State→Goal Links: For each (g,Δ) where |Δ|≥θ_goal (default 0.05):
   - Create CausalLink(Δs_t, Satisfaction(g))
   - Create SatisfactionDelta(g, Δ)

Temporal Credit Assignment:
- Eligibility traces: Maintain e_t(action, goal) = γ_g × λ_g × e_{t-1}(action, goal) + indicator(action at t)
  - γ_g ∈ [0,1]: goal-specific discount factor (temporal scope of goal)
  - λ_g ∈ [0,1]: goal-specific eligibility decay rate
  - Defaults: Safety/INTEGRITY_PRESERVATION (γ=0.95, λ=0.9), EXPLORATION/NOVELTY_PURSUIT (γ=0.8, λ=0.7), ENERGY_REGULATION (γ=0.99, λ=0.95), POSITIVE_EMOTION (γ=0.7, λ=0.6)
- Lag inference: For each (action, goal) pair across N episodes:
  - Compute cross-correlation or mutual information between action occurrences and goal deltas
  - Lag τ = argmax(correlation/MI) within horizon H (default H=10)
  - Store distribution: (action, goal, context) → (τ_mean, τ_std)
- Attribution weight distribution: For goal delta Δg at time t:
  - weight(a, g) = e_t(a, g) × lag_weight(a, g, t) where lag_weight uses pdf(t - t_a | τ_mean, τ_std)
  - Normalize weights across all actions to sum ≤ 1.0 within horizon
- Confidence calibration: confidence(a, g, ctx) = α × accuracy + β × consistency + γ × reliability
  - accuracy: 1 - MAE of predicted vs. actual goal deltas on held-out episodes
  - consistency: 1 - variance of attribution weights across episodes
  - reliability: context stability score (higher for deterministic environments)
  - Default weights: α=0.5, β=0.3, γ=0.2

Pattern Mining & Compression:
- Export phase: Publish CausalLink and Attribution facts to &miner space (hyperon-miner compatible)
- Discovery phase: Run frequent pattern mining with min_support threshold (default 3)
- Filter motifs by surprisingness score (threshold 0.5) to identify causal vs. spurious patterns
- Abstraction phase: Replace frequent subgraphs (≥3 instances) with Motif nodes
- Prior refinement: Update lag distributions conditioned on motif context using context-grouped statistics
- Metrics: Track compression ratio = (original_edges - final_edges) / original_edges (target ≥25%)

Persistence:
- MORK integration: Save Atomspace spaces (&kb, &miner) with incremental append support
- Round-trip verification: Load → compare atoms → assert fidelity ≥95%
- Performance tracking: Log save/load latency, file size growth, query performance

Integration Details

MeTTa/Atomspace Integration:
- Construct subgraphs and serialize to MeTTa expressions
- Follow metta-best-practices: separate spaces (&kb for facts, &self for rules/queries, &miner for mining, &tests for test scaffolds)
- Expose queries to MAGUS/AIRIS via MeTTa functions: get-attributions, get-causal-chain, suggest-actions
- All public functions include type signatures: (: function-name (-> ArgType1 ArgType2 ReturnType))

MAGUS Integration:
- Primary API: GetAttributions(goal, context, horizon) → List[(action, lag, weight, confidence)]
  - Returns actions historically attributed to goal satisfaction in similar contexts
  - Used in MAGUS scoring-v2 pipeline to boost considerations for high-attribution actions
  - Context includes modulators (pleasure, arousal, dominance, focus, resolution, exteroception)
- Secondary API: SuggestActions(goal, context, k) → List[(action, expected_impact, confidence)]
  - Returns top-k actions ranked by (weight × confidence) for achieving goal
- Goal taxonomy: Use canonical MAGUS goal IDs from ../metta-magus/ (JOY, GROWTH, CHOICE hierarchies)
- Modulator filtering: Query attributions from episodes with similar modulator values (±0.2 tolerance)
- Integration point: MAGUS can augment scoring-v2 with HERMES-derived attribution boosts:
  final_score = base_score + hermes_boost + metagoal_effects + overgoal_adjustment

AIRIS Integration:
- Input: AIRIS episode logs with predictions and outcomes
- Mapping: AIRIS curiosity → MAGUS CURIOSITY_SATISFACTION/EXPLORATION goals
- Processing: Convert AIRIS episodes to HERMES trace format; ingest and construct causal graph
- Output: GetGoalHints(current_state, predictions) → List[(goal, expected_delta, confidence)]
  - Suggests which MAGUS goals likely to change given predicted state transitions
  - Enables AIRIS to prioritize exploration toward valuable goal satisfaction
- Feedback loop: AIRIS explores → HERMES learns patterns → HERMES suggests → AIRIS refines exploration

Pattern Miner Integration:
- Reference implementations: ../../hyperon reference/hyperon-miner, ../../hyperon reference/hyperon-miner-2
- Approach: Publish facts to &miner space → invoke miner with min_support → consume motifs → compress graph
- Motif abstraction: Replace (pickup $brick) → (place $brick) patterns with Motif nodes
- Prior refinement: Use motif context to update lag distributions (e.g., brick moves have lag=1-2 in MoveCube scenario)
- Scheduling: Run miner after every 10 episodes (batch mode) or incrementally if miner-2 supports streaming

MORK Persistence Integration:
- Reference: ../../hyperon reference/MORK
- Operations: save_space(&kb, path), load_space(path) → Space
- Incremental saves: Append new episode atoms without full rewrite
- Fidelity testing: Round-trip load→save→load comparison; assert ≥95% atom preservation
- Performance metrics: Track save/load latency (target ≤1s save, ≤5s load for 100 episodes)
- Query optimization: MORK-accelerated queries avoid full space load for attribution lookups

Evaluation

Causal Fidelity & Goal Correlation:
- Pearson/Spearman correlation between predicted and observed goal deltas (target: r ≥ 0.7 for primary goals)
- Mutual information between actions and goals (target: MI ≥ 0.5 for high-attribution actions)
- False positive/negative rates for causal links in controlled scenarios (target: FP ≤10%, FN ≤15%)
- Lag inference accuracy: MAE between inferred and actual lags (target: ≤1.5 steps)
- Methodology: Compare HERMES graph to ground truth in Hello Cube and Move Cube scenarios

Reasoning Utility in MAGUS:
- Success rate uplift: % increase in task completion vs. baseline MAGUS without HERMES (target: ≥30%)
- Planning efficiency: Reduction in average actions to goal (target: ≥25%)
- Goal satisfaction: Integrated satisfaction over episode (target: ≥20% increase)
- Exploration efficiency: Reduction in redundant state visits (target: ≥15%)
- Methodology: A/B testing MAGUS with vs. without HERMES; 100 episodes per condition; statistical significance p<0.05

Symbolic Compression:
- Compression ratio: (original_edges - final_edges) / original_edges after motif abstraction (target: ≥25%)
- Redundancy score: Count of duplicate subgraphs (target: ≤10% after compression)
- Motif utility: Frequency of motif references vs. explicit subgraphs (target: ≥60% replacement)
- Correctness: Queries on compressed graph match original graph results

Performance & Scalability:
- Construction time: Process 1000-step episode (target: ≤10s)
- Export time: Serialize episode to MeTTa (target: ≤2s for 1000 steps)
- Query latency: Attribution lookup (target: ≤100ms)
- Memory footprint: RAM usage for 100-episode dataset (target: ≤2GB)
- MORK latency: Save/load times (target: ≤1s save, ≤5s load for 100 episodes)
- Scalability testing: Vary episode lengths (100, 1000, 10000 steps) and dataset sizes (10, 100, 1000 episodes)

Test Scenarios:
- Hello Cube: Simple pickup/place task; expected lag=0 for immediate effects, attribution weight ≈1.0 for goal completion
- Move Cube (heavy): Decomposed task with repeated brick moves; expected lag=1-2 for delayed satisfaction, motif discovery
- Accelerated 100-epoch run: Long-term convergence testing; verify weight/lag stability, confidence increase, compression plateau
- Robustness tests: Noisy observations (20% missing data), sparse episodes (<20 steps), multi-agent confusion

Milestones (aligned with Hermes V4)
- M1 — Foundation and Prototyping: architecture, integration points, basic extractor prototype, MeTTa format, sample outputs, evaluation plan.
- M2 — Graph Toolchain and Integration: full constructor, goal annotation/confidence, Atomspace+MeTTa export, MORK persistence, AIRIS/MAGUS connectors, midpoint MAGUS integration test, API/CLI docs.
- M3 — Evaluation, Optimization, Release: evaluation suite, optimizations, open‑source release, sample data and scripts, notebooks, Neoterics demo, community submission.

Deliverables
- MeTTa modules (types, constructors, queries, tests), ingestion and construction service, Atomspace writer + MORK harness, CLI tools, documentation.

Open Questions
- Provide a canonical list of MAGUS goals/subgoals and modulators from ../metta-magus/ for initial node IDs, including any short names.
- Desired default horizon H and goal‑specific γ_g, λ_g; any domain‑specific priors for lag distributions.
- Preferred API exposure beyond MeTTa (HTTP/gRPC/message bus) and expected throughput.
- Target hardware profile for performance baselines and MORK configuration.

