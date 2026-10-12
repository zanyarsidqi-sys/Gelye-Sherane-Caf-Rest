# Upgrade 514 — Staff order waiting-time triage

- Added optional age-based queue filter with 15/30/60/120-minute thresholds.
- Shows per-item waiting age at the last successful board refresh, not a live timer.
- Excludes delivered items and rejects missing/future timestamps from waiting alerts.
- Preserves authorization-scoped Supabase RPC and existing search/table/stage filters.
- Advisory only; no new RPC, migration, SLA enforcement or financial mutation.

Verification: archive integrity only; Flutter compilation and live Supabase testing pending.
