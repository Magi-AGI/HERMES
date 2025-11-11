HERMES Documentation
Last Updated: November 11, 2025

This folder contains specifications and guides to implement HERMES, the Hypergraph Experiential Reasoning & Motivational Engagement System.

System Overview
HERMES bridges experiential learning (AIRIS) and goal-directed reasoning (MAGUS) by constructing causal hypergraphs that link Actions → State Changes → Goal Satisfaction with temporal credit assignment and confidence calibration.

Key Capabilities:
- Extract causal relationships from agent traces with delayed rewards
- Assign temporal credit using eligibility traces and lag inference
- Discover and abstract recurring patterns via hyperon-miner integration
- Enhance MAGUS decision-making with historical attribution data
- Guide AIRIS exploration toward valuable goal satisfaction
- Persist knowledge in Atomspace via MORK with ≥95% fidelity

Contents (Updated November 11, 2025)
- spec/hermes-spec.md — End-to-end specification (v0.2) with detailed algorithms
- architecture.md — Component architecture with detailed descriptions and data flow
- data-model.md — Atomspace/MeTTa schema with full MAGUS goal taxonomy and modulators
- message-contracts.md — Trace ingestion and export formats
- api.md — Programmatic API and MeTTa queries
- integration-hyperon.md — Hyperon integrations (pattern miner, MORK, Atomspace)
- scenarios.md — Test scenarios (Hello Cube, Move Cube, 100-epoch, robustness tests)
- evaluation.md — Metrics, benchmarks, and evaluation methodology
- goals.md — MAGUS goal taxonomy with temporal parameters and integration guidelines
- milestones.md — Phased delivery plan (M1: Foundation, M2: Integration, M3: Release)
- open-questions.md — Pending decisions and implementation risks
- metta/examples.metta — Example MeTTa expressions for tests
- metta/hermes-demo.metta — Demo MeTTa module with sample facts and queries

Quick Start for Implementation
1. Read spec/hermes-spec.md for complete system specification (start here!)
2. Review architecture.md to understand component responsibilities and data flow
3. Study data-model.md for MAGUS goal taxonomy and Atomspace schema
4. Check scenarios.md for concrete test cases and expected outputs
5. Consult integration-hyperon.md for Hyperon-specific implementation details

Key Concepts

Temporal Credit Assignment:
- Eligibility traces: e_t(a,g) = γ_g × λ_g × e_{t-1}(a,g) + 1 if action a taken
- Goal-specific parameters: Safety (γ=0.95, λ=0.9), POSITIVE_EMOTION (γ=0.7, λ=0.6)
- Lag inference: τ = argmax(cross_correlation) or argmax(mutual_information)
- Confidence: 0.5×accuracy + 0.3×consistency + 0.2×reliability

MAGUS Integration:
- GetAttributions(goal, context, horizon) → List[(action, lag, weight, confidence)]
- SuggestActions(goal, context, k) → Top-k actions ranked by impact
- Goal hierarchy: JOY (pleasure, emotion, creativity), GROWTH (competence, ethics), CHOICE (autonomy, meaning)
- Modulators: pleasure, arousal, dominance, focus, resolution, exteroception [0,1]

Pattern Mining:
- Export CausalLink facts to &miner space
- Run hyperon-miner with min_support=3
- Filter by surprisingness score ≥0.5
- Abstract frequent subgraphs to Motif nodes
- Target: ≥25% compression ratio

Success Criteria:
- Causal fidelity: r ≥ 0.7, lag MAE ≤ 1.5 steps, FP ≤10%, FN ≤15%
- MAGUS utility: ≥30% success rate improvement vs. baseline
- Compression: ≥25% edge reduction after motif abstraction
- Performance: ≤10s per 1000-step episode, ≤100ms query latency
- Persistence: ≥95% MORK round-trip fidelity

Recent Updates (November 11, 2025)
- Added detailed algorithm specifications with concrete formulas
- Expanded MAGUS goal taxonomy with full hierarchy and temporal parameters
- Enhanced component descriptions with validation criteria
- Added comprehensive test scenarios with expected behaviors
- Clarified integration patterns for MAGUS scoring-v2 pipeline
- Documented modulator effects and context filtering

Related Repositories
- MeTTa/MAGUS specifics: ../metta-magus/ (Milestones 2-4 with validated metrics)
- Pattern miner references: ../../hyperon reference/hyperon-miner, ../../hyperon reference/hyperon-miner-2
- MORK persistence: ../../hyperon reference/MORK

Next Steps
1. Clarify open questions in open-questions.md with stakeholders
2. Set up development environment (Python 3.8+, Hyperon 0.2.1+)
3. Implement M1 deliverables: Ingestion module, basic causal extractor, MeTTa output
4. Create test harness for Hello Cube scenario
5. Begin integration testing with MAGUS scoring-v2

