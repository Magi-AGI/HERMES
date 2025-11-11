API Outline

MeTTa‑First Queries
- Provide modules exposing queries to retrieve:
  - Attributions by goal/context/horizon: `(get-attributions $goal $ctx $h)`
  - Causal chain for an action: `(get-causal-chain $action $window)`
  - Top‑k suggested actions for a goal: `(suggest-actions $goal $ctx $k)`

HTTP/gRPC (optional)
- POST /ingest — batch ingest of trace events (JSON array or NDJSON)
- GET /graph/attributions?goal=Safety&h=10&context=... — returns JSON list
- GET /graph/motifs?min_support=3 — frequent patterns/motifs (JSON or MeTTa)
- POST /magus/suggest-actions — { goal, context, horizon, k } → ranked actions

Response Schemas
- Attribution
```
{
  "action": {"name":"pickup","args":{"object":"cube"}},
  "goal": "Resource",
  "lag": 0,
  "weight": 0.22,
  "confidence": 0.79,
  "context": {"scenario":"HelloCube"}
}
```

CLI (developer utilities)
- hermes ingest traces.jsonl
- hermes export --format metta --episode hello-cube-001
- hermes query --goal Safety --horizon 10 --top 5

Notes
- Keep API optional; MeTTa integration is the primary path for Hyperon users.
- Ensure module and function names follow metta-best-practices.

