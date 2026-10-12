# Dashboard Upgrade 92 — Visit-wide checkout safety

Added read-only `gs_visit_settlement_gate(visit_id)` to inspect the **whole
active table visit**, rather than incorrectly treating one order as the bill.

It aggregates provisional totals and reconciliation exceptions from every
order linked to that visit, detects older orders on the physical table without
an authoritative visit link, and reports a specific checkout blocker.

**Checkout always remains blocked.** No reliable provider settlement, verified
owner waiver, physical departure, cleaning or shisha-completion certificate is
implemented. Historical orders must not be automatically attributed to a
visit merely because their table numbers match.

The function is a draft requiring PostgreSQL schema compatibility checks and
Supabase staging execution. ZIP integrity was verified; no Flutter compilation
or live database tests were performed.
