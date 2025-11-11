Test Scenarios for HERMES Evaluation

Purpose: Validate causal extraction, temporal credit assignment, and pattern mining capabilities

Scenario 1: Hello Cube (Simple Task)

Description:
- Agent approaches a table with a small cube at point A and moves it to point B
- Task requires two actions: pickup cube, place cube at target
- Goal satisfaction: TaskCompletion increases upon successful placement
- Expected lag: 0 (immediate feedback)
- Complexity: Low (2-step linear sequence)

Expected HERMES Behavior:
```
(CausalLink (pickup cubeA) (inventory added cubeA))
(CausalLink (place cubeA pointB) (world placed cubeA pointB))
(CausalLink (world placed cubeA pointB) (Satisfaction TaskCompletion))
(SatisfactionDelta TaskCompletion +0.4)
(Attribution (place cubeA pointB) TaskCompletion 0 0.35 0.85)
```

Validation Criteria:
- Correlation with ground truth: r ≥ 0.9
- Lag inference: τ = 0 ± 1 step
- Attribution weight for place action: ≥ 0.9 (dominates credit)
- Confidence: ≥ 0.8 after 5 episodes
- No spurious causal links (FP rate = 0)

Scenario 2: Move Cube (Complex Task with Decomposition)

Description:
- Gold cube on Table A is too heavy to lift directly
- Agent discovers cube is composed of 10 individual bricks
- Agent moves bricks individually from Table A to Table B
- Goal satisfaction: ResourceTransfer increases incrementally as bricks accumulate
- Expected lag: 1-2 steps (delayed satisfaction as multiple bricks needed)
- Complexity: High (repeated pattern, delayed reward, partial progress)

Expected HERMES Behavior:
```
(CausalLink (examine cube_gold) (knowledge discovered (composition bricks)))
(CausalLink (pickup brick_i) (inventory added brick_i))
(CausalLink (place brick_i tableB) (cube_progress increased))
(CausalLink (cube_progress increased) (Satisfaction ResourceTransfer))
(SatisfactionDelta ResourceTransfer +0.3)
(Attribution (pickup brick_i) ResourceTransfer 1 0.12 0.78)
```
- Temporal lag: attribution should reflect delayed satisfaction as bricks accumulate.
- Miner should identify repeated (pickup→place→progress→satisfaction) motif.

Motif Discovery:
- Pattern: (pickup $brick) → (place $brick tableB) → (progress increased)
- Frequency: 10 instances across episode
- Abstraction: Motif node "brick_move_pattern" replaces 10 explicit subgraphs
- Compression ratio: ≥ 30% edge reduction

Validation Criteria:
- Lag inference: τ = 1-2 steps for brick moves
- Attribution weights: Distributed across all 10 brick moves (≈0.1 each)
- Confidence: ≥ 0.75 for individual brick attributions
- Motif discovery: Pattern found with min_support=3
- Surprisingness: Score ≥ 0.5 (causal, not spurious)

Scenario 3: Accelerated 100-Epoch Run (Convergence Testing)

Description:
- Mix of Hello Cube and Move Cube scenarios
- 100 episodes total with randomized seeds
- Evaluation checkpoints: Every 10 episodes
- Goal: Verify long-term stability and convergence

Expected HERMES Behavior:

Convergence Dynamics:
- Episodes 1-20: Attribution weights have high variance, lags uncertain
- Episodes 20-40: Weights stabilize (variance ≤ 0.15), lags converge to true values
- Episodes 40-100: Refinement phase (confidence increases, compression improves)

Metrics Tracking:
- Weight variance: Should decrease monotonically, plateau < 0.1 by episode 30
- Lag MAE: Should decrease to ≤ 1.0 by episode 20
- Confidence: Should increase asymptotically toward 0.85-0.90
- Compression ratio: Should increase to 40-50% by episode 50, then plateau
- Processing time: Should remain ≤ 15 minutes total for 100 episodes

Validation Criteria:
- Attribution convergence: Weight variance ≤ 0.1 after 30 episodes
- Lag stability: Lag MAE ≤ 1.0 after 20 episodes
- Confidence growth: ≥ 0.8 for frequent patterns by episode 50
- Compression plateau: Ratio stabilizes around 40-50% after episode 50
- Performance: Total runtime ≤ 15 minutes on reference hardware

Scenario 4: Robustness Testing (Adversarial Conditions)

Noisy Observations:
- Randomly drop 20% of state keys per timestep
- Add Gaussian noise (σ=0.1) to goal values
- Expected: Confidence calibration reduces noisy attributions to < 0.6
- Target: Fidelity ≥ 0.6 despite noise

Sparse Episodes:
- Episodes with < 20 steps (limited data)
- Expected: System falls back to prior distributions
- Attributions marked as "tentative" (confidence ≤ 0.5)
- No system crashes or invalid outputs

Multi-Agent Confusion:
- Interleaved traces from 3 agents acting simultaneously
- Context tags distinguish agents
- Expected: FP rate ≤ 15% (some cross-contamination acceptable)
- Context filtering prevents most cross-attribution

Validation Criteria:
- Noisy data: Fidelity ≥ 0.6, confidence appropriately reduced
- Sparse data: Graceful degradation, no crashes
- Multi-agent: FP rate ≤ 15% with proper context tagging

