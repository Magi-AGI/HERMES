Data Model (Atomspace and MeTTa)
Last Updated: November 11, 2025

Overview:
HERMES uses Hyperon's Atomspace to represent causal knowledge as a hypergraph. All entities and relations are serializable to MeTTa expressions following metta-best-practices (space separation, type signatures, PascalCase for types).

Entity Types

Action:
- Concrete action taken by an agent
- Representation: (action_name args) or (action_name) for parameterless actions
- Examples: (pickup cube), (move-to door), (examine object), (press red_button)
- Source: Extracted from trace "action" field

StateDelta:
- Symbolic representation of state change between timesteps s_t and s_{t+1}
- Representation: Domain-specific symbolic atoms
- Examples:
  - (inventory added cube) — item added to inventory
  - (gate open) — binary state flip
  - (energy decreased 0.1) — numeric change
  - (world placed cube pointB) — world state update
- Source: Computed by State Differencing module using pluggable mappers

Goal:
- MAGUS goal or subgoal identifier from canonical taxonomy (../metta-magus/)
- Hierarchy: JOY, GROWTH, CHOICE (top-level) with nested subgoals
- Examples: Safety, ENERGY_REGULATION, CURIOSITY_SATISFACTION, NOVELTY_PURSUIT, POSITIVE_EMOTION
- Full taxonomy: See goals.md and Appendix below
- Usage: Referenced in SatisfactionDelta and Attribution atoms

Context:
- Metadata tags describing episode conditions
- Fields: environment, agent type, scenario, RNG seed, modulators
- Modulators (Bach's 6): pleasure, arousal, dominance, focus, resolution, exteroception (all [0,1])
- Representation: ContextTag atoms linking context ID to key-value pairs
- Usage: Filtering queries, context-conditional lag distributions

Episode/Step:
- Provenance bookkeeping for trace origins
- Episode: Unique identifier for contiguous trace sequence
- Step: Timestep index within episode
- Representation: OccursIn links and TimeWindow annotations
- Usage: Episode-scoped queries, temporal filtering

Relations (MeTTa signatures are conceptual)
- (CausalLink $src $dst : (-> Atom Atom))
- (SatisfactionDelta $g $delta : (-> Goal Number))
- (Attribution $a $g $lag $weight $confidence : (-> Action Goal Number Number Number))
- (ContextTag $c $k $v)
- (OccursIn $node $episode) ; (TimeWindow $start $end)

Attributes
- weight ∈ [0,1]: normalized contribution of action to goal within a window.
- confidence ∈ [0,1]: calibration of link strength based on predictive accuracy, consistency, and context reliability.
- lag ∈ Z≥0: estimated delay (in steps) between action and its primary contribution to goal satisfaction.

Type/Name Conventions
- Use PascalCase for concept/type atoms (e.g., Action, Goal, StateDelta).
- Use kebab-case or camelCase for functions/relations (e.g., get-attributions, causal-link).
- Organize MeTTa modules per metta-best-practices with separate spaces for facts (&kb) and rules/queries (&self).

Example MeTTa Atoms
```
(: CausalLink (-> Atom Atom))
(: SatisfactionDelta (-> Goal Number))
(: Attribution (-> Action Goal Number Number Number))

(CausalLink (press red_button) (gate open))
(CausalLink (gate open) (Satisfaction Safety))
(SatisfactionDelta Safety +0.4)
(Attribution (press red_button) Safety 1 0.35 0.82)
```

Goal Taxonomy Integration

MAGUS Goal Hierarchy (Canonical from ../metta-magus/):

JOY — Positive experience and wellbeing
├── PLEASURE_ATTAINMENT — Seeking pleasurable experiences
│   ├── POSITIVE_EMOTION — Maximizing positive emotional states
│   └── PLAY_ENGAGEMENT — Engagement in playful activities
├── EMOTIONAL_REGULATION — Managing emotional states
│   ├── AROUSAL_MANAGEMENT — Regulating activation/excitement level
│   └── DOMINANCE_BALANCING — Balancing sense of control
├── COGNITIVE_COHERENCE — Mental consistency and understanding
├── RELATEDNESS — Social connection
│   ├── AFFILIATION — Building social bonds
│   └── LOYALTY — Maintaining commitments
└── CREATIVITY_BEAUTY — Aesthetic and creative pursuits
    ├── BEAUTY_SEEKING — Pursuing aesthetic experiences
    ├── INTERESTINGNESS — Seeking interesting stimuli
    └── COMPRESSION_DRIVE — Finding patterns and simplifications

GROWTH — Development and learning
├── COMPETENCE — Capability development
│   ├── SKILL_ACQUISITION — Learning new skills
│   ├── ENERGY_REGULATION — Managing resource levels
│   └── INTEGRITY_PRESERVATION — Maintaining physical/functional integrity
├── GROWTH_ORIENTATION — Drive for improvement
│   ├── CURIOSITY_SATISFACTION — Fulfilling curiosity
│   │   ├── EXPLORATION_INCENTIVE — Motivation to explore
│   │   └── NOVELTY_PURSUIT — Seeking novel experiences
│   └── CREATIVITY_EXPRESSION — Creative output
│       └── INNOVATION_PROMOTION — Encouraging innovative approaches
├── CERTAINTY_SEEKING — Reducing uncertainty
├── ETHICAL_CONDUCT — Moral behavior
│   ├── FAIRNESS — Promoting justice and fairness
│   ├── CARE — Providing care and compassion
│   ├── AUTHORITY — Recognizing legitimate authority
│   └── PURITY — Maintaining purity/sanctity
└── ALIEN_GOALS — Non-human cognitive goals
    ├── INFO_DENSITY_OPT — Optimizing information density
    ├── PATTERN_RECOGNITION — Identifying patterns
    ├── COMPLEXITY_MANAGEMENT — Managing complexity
    └── SYMMETRY_APPRECIATION — Recognizing symmetry

CHOICE — Autonomy and meaning
├── AUTONOMY — Self-determination
│   └── FREEDOM_PRESERVATION — Maintaining freedom of choice
└── MEANING_CREATION — Purpose and significance
    └── IDENTITY_FORMATION — Developing sense of self

Motivational grounding
- The MAGUS goals above and the modulators used in Context are grounded in the OpenPsi / PSI-theory style demand system and Bach’s six-modulator framework, as synthesized in the MAGUS research materials (for example, the “Paper Synthesis: OpenPsi, ROCCA, and Metagoals for MAGUS” card in the magi-archive Decko wiki).
- HERMES treats these goal and modulator symbols as externally defined; its responsibility is to record how actions influence their satisfaction over time, not to re-specify their internal dynamics.

Modulators (Bach's 6-Modulator Framework):
- pleasure ∈ [0,1]: Emotional valence (negative → positive)
  - Effect on scoring: 0.9 + 0.2×pleasure → [0.9, 1.1] multiplier
- arousal ∈ [0,1]: Activation level (calm → excited)
  - Effect on scoring: 0.8 + 0.4×arousal → [0.8, 1.2] multiplier
- dominance ∈ [0,1]: Sense of control (submissive → dominant)
  - Effect on scoring: 0.85 + 0.3×dominance → [0.85, 1.15] multiplier
- focus ∈ [0,1]: Attention span (unfocused → laser-focused)
  - Effect on scoring: 0.7 + 0.6×focus → [0.7, 1.3] multiplier
- resolution ∈ [0,1]: Detail level (abstract → concrete)
  - Effect on scoring: 0.75 + 0.5×resolution → [0.75, 1.25] multiplier
- exteroception ∈ [0,1]: External awareness (internal → external)
  - Effect on scoring: 0.8 + 0.4×exteroception → [0.8, 1.2] multiplier

Usage in HERMES:
- Goals: Use exact symbols from taxonomy in Attribution and SatisfactionDelta atoms
- Hierarchical queries: Query for "GROWTH" returns attributions for all GROWTH subgoals
- Modulators: Include in Context for filtering (±0.2 tolerance for similarity matching)
- MAGUS Integration: HERMES attributions inform scoring-v2 pipeline adjustments

Context and Provenance
- (ContextTag $ctx key value) atoms persist run‑time metadata.
- (OccursIn $node $episode) and (TimeWindow $start $end) support windowed queries.

Persistence
- Use MORK to persist Atomspace contents; measure round‑trip fidelity of all above atoms.
