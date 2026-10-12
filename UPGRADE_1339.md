# Upgrade 1339 — financial refresh coherence

- Payments Management refresh actions now reload the cash-only sample, reconciliation readiness and independently authorized live-balance RPC together.
- Dashboard normal/automatic refresh also re-requests its permission-gated live-balance RPC; old verified values are not silently retained when the new result is incomplete.
- Unavailable cards explicitly require verified all-method settlement reporting.
- No canonical payment allocation or motel prepayment finality is claimed; no database schema changes in this upgrade.
- Runtime Flutter build, deployed Supabase and visual screenshot parity remain untested in this environment.
