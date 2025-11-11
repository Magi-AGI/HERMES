MAGUS Goals and Modulators (Provisional)

Notes
- Canonical MAGUS taxonomy is defined in ../metta-magus/. This document captures a stable subset for HERMES integration and assigns short IDs.
- Use these symbols in MeTTa and as JSON keys for goal snapshots in logs.

Primary Goals
- JOY (Joy)
  - PLEASURE_ATTAINMENT (Pleasure Attainment)
    - POSITIVE_EMOTION (Positive Emotion Maximization)
    - PLAY_ENGAGEMENT (Play Engagement)
  - EMOTIONAL_REGULATION (Emotional Regulation)
    - AROUSAL_MANAGEMENT (Arousal Management)
    - DOMINANCE_BALANCING (Dominance Balancing)
  - COGNITIVE_COHERENCE (Cognitive Coherence)
  - RELATEDNESS (Relatedness)
    - AFFILIATION (Affiliation Cultivation)
    - LOYALTY (Loyalty Development)
  - CREATIVITY_BEAUTY (Creativity and Beauty)
    - BEAUTY_SEEKING (Beauty Seeking)
    - INTERESTINGNESS (Interestingness Detection)
    - COMPRESSION_DRIVE (Compression Drive)

- GROWTH (Growth)
  - COMPETENCE (Competence Development)
    - SKILL_ACQUISITION (Skill Acquisition)
    - ENERGY_REGULATION (Energy Regulation)
    - INTEGRITY_PRESERVATION (Integrity Preservation)
  - GROWTH_ORIENTATION (Growth Orientation)
    - CURIOSITY_SATISFACTION (Curiosity Satisfaction)
      - EXPLORATION_INCENTIVE (Exploration Incentive)
      - NOVELTY_PURSUIT (Novelty Pursuit)
    - CREATIVITY_EXPRESSION (Creativity Expression)
      - INNOVATION_PROMOTION (Innovation Promotion)
  - CERTAINTY_SEEKING (Certainty Seeking)
  - ETHICAL_CONDUCT (Ethical Conduct)
    - FAIRNESS (Fairness Promotion)
    - CARE (Care Provision)
    - AUTHORITY (Authority Recognition)
    - PURITY (Purity Maintenance)
  - ALIEN_GOALS (Alien/Non-Human Goals)
    - INFO_DENSITY_OPT (Information Density Optimization)
    - PATTERN_RECOGNITION (Pattern Recognition)
    - COMPLEXITY_MANAGEMENT (Complexity Management)
    - SYMMETRY_APPRECIATION (Symmetry Appreciation)

- CHOICE (Choice)
  - AUTONOMY (Autonomy)
    - FREEDOM_PRESERVATION (Freedom Preservation)
  - MEANING_CREATION (Meaning Creation)
    - IDENTITY_FORMATION (Identity Formation)

Modulators (Bach’s six)
- pleasure — [0,1]
- arousal — [0,1]
- dominance — [0,1]
- focus — [0,1]
- resolution — [0,1]
- exteroception — [0,1]

Conventions and Usage Guidelines

Naming in MeTTa:
- Goal symbols use PascalCase or UPPER_SNAKE_CASE from MAGUS taxonomy
- Prefer human-readable forms: Safety, ENERGY_REGULATION, CURIOSITY_SATISFACTION
- Satisfaction wrapper: (Satisfaction GoalName) for goal satisfaction concepts
- Short IDs map to stable JSON keys in trace ingestion

Modulator Integration:
- Include modulators in `context` field of traces: {"arousal": 0.2, "focus": 0.8}
- HERMES uses modulators for:
  - Context-conditional lag distributions (high arousal → different action-goal lags)
  - Attribution filtering (match similar modulator values ±0.2)
  - Confidence calibration (consistency across modulator states)
- Modulators affect MAGUS scoring but HERMES treats them as context metadata

Goal-Specific Temporal Parameters:
Based on goal temporal scope (informed by MAGUS Milestone 3):

Long-term goals (γ=0.95, λ=0.9, horizon=15):
- Safety, INTEGRITY_PRESERVATION, LOYALTY
- Rationale: Consequences manifest over extended periods

Medium-term goals (γ=0.8, λ=0.7, horizon=10):
- EXPLORATION_INCENTIVE, NOVELTY_PURSUIT, SKILL_ACQUISITION, CERTAINTY_SEEKING
- Rationale: Moderate delay between action and satisfaction

Short-term goals (γ=0.7, λ=0.6, horizon=5):
- POSITIVE_EMOTION, AROUSAL_MANAGEMENT, PLAY_ENGAGEMENT
- Rationale: Immediate or near-immediate feedback

Resource goals (γ=0.99, λ=0.95, horizon=20):
- ENERGY_REGULATION
- Rationale: Both immediate and long-term consequences

HERMES-MAGUS Integration:
- MAGUS Overgoal: Composite metric based on M2 weighted correlations (avg ≈0.318)
  - HERMES treats overgoal as part of MAGUS scoring context, not a separate attribution target
- MAGUS Metagoals (Coherence, Exploration, Safety):
  - HERMES attributes to underlying goals, not metagoals directly
  - Metagoals influence MAGUS action selection, creating patterns HERMES observes
- HERMES attributions feed into MAGUS scoring-v2 pipeline:
  - Boost considerations for actions with strong historical attribution
  - Provide temporal lookahead (lag-adjusted future satisfaction predictions)

Query Patterns:
- Specific goal: (get-attributions ENERGY_REGULATION $ctx 10)
- Goal hierarchy: (get-attributions GROWTH $ctx 10) → all GROWTH subgoals
- Modulator filter: Context with {"arousal": 0.3} matches episodes with arousal ∈ [0.1, 0.5]
- Top actions: (suggest-actions Safety $ctx 5) → 5 best actions for Safety

Trace JSON Format:
```json
{
  "episode_id": "demo-001",
  "t": 42,
  "action": {"name": "examine", "args": {"object": "door"}},
  "state": {"position": [3,4], "inventory": ["keycard"]},
  "goals": {
    "Safety": 0.62,
    "ENERGY_REGULATION": 0.45,
    "EXPLORATION_INCENTIVE": 0.78,
    "CURIOSITY_SATISFACTION": 0.65
  },
  "context": {
    "scenario": "LockedRoom",
    "agent": "NeoAgent1",
    "pleasure": 0.5,
    "arousal": 0.3,
    "dominance": 0.6,
    "focus": 0.7,
    "resolution": 0.5,
    "exteroception": 0.8
  }
}
```

