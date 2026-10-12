# Upgrade 475 — Permission-safe operational attention

Adds actionable read-only attention indicators for kitchen workload, ready-to-serve orders, and fully occupied tables, derived exclusively from existing permission-scoped Dashboard RPC data.

## Safety
- Missing/restricted fields never treated as zero.
- No fabricated overdue thresholds or financial figures.
- No new migration required.
- No mutation or credit functionality enabled.

## Remaining
Financial KPIs require verified ledger integration; navigation shortcuts, full KPI reconciliation, responsive/accessibility testing, live Supabase and Flutter testing still pending.

Section 01 estimate: **78% provisional coding progress** (previously 75%). No live verification performed.
