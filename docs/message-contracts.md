Message Contracts

Trace In (JSON; batch or stream)
- episode_id: string
- t: integer (step index)
- action: { name: string, args?: object|array }
- state: { key: value }  ; raw observation snapshot
- goals: { goal_name: number } ; MAGUS goal satisfaction snapshot
- predictions?: { key: value } ; optional AIRIS predictions
- context?: { key: value } ; env, agent type, scenario id, RNG seed, modulators

Origin of goals and modulators
- The `goals` vector comes from the MAGUS goal taxonomy and demand system (JOY / GROWTH / CHOICE and subgoals) defined in `../metta-magus/` and summarized in the MAGUS research notes (for example, the “Paper Synthesis: OpenPsi, ROCCA, and Metagoals for MAGUS” card in the magi-archive wiki).
- Modulator fields in `context` (pleasure, arousal, dominance, focus, resolution, exteroception) follow the OpenPsi / Bach six-modulator framework; HERMES treats these as contextual features but does not redefine their dynamics.

Example
```
{
  "episode_id": "hello-cube-001",
  "t": 42,
  "action": { "name": "pickup", "args": { "object": "cube" } },
  "state": { "room": "lab", "inventory": ["cube"], "door": "closed" },
  "goals": { "Safety": 0.62, "Exploration": 0.44 },
  "predictions": { "door_state_next": "open?" },
  "context": { "env": "sim", "agent": "NeoAgent1", "scenario": "HelloCube", "arousal": 0.2 }
}
```

Graph Out (MeTTa examples)
```
(CausalLink (pickup cube) (inventory added cube))
(CausalLink (inventory added cube) (Satisfaction Resource))
(SatisfactionDelta Resource +0.3)
(Attribution (pickup cube) Resource 0 0.22 0.79)
```

Error/Status
- Ingestion returns { accepted: count, rejected: count, reasons?: [...] }.
- Export endpoints return MeTTa text or JSON payloads as requested.
