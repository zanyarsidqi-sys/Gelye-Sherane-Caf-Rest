# Upgrade 1212 — Replacement handoff consistency review

Expanded the existing staff-only `gs_replacement_handoff_consistency` RPC (same name/signature) to report 14 independently detectable consistency issues, including timestamp order, missing audit events, tasks created before preparation readiness, and contradictory assignment states. Results are read-only, capped at 200, and require authenticated Table Orders view permission.

The Table Orders replacement progress screen now displays human-readable diagnostic explanations, an expandable findings list, and a filter for affected replacements. It continues to poll every 15 seconds while mounted.

**Integration boundary:** No auto-repair or financial changes; no physical printer or phone push integration. Flutter compilation and live Supabase verification deferred until laptop access. SQL must be applied in migration order and tested against the actual database before production use.
