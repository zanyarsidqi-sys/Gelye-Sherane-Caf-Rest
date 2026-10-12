# Dashboard Upgrade 115 — Cash-only visit release operation

**New operation:** `gs_release_cash_only_table_visit(visit_id)` closes an
eligible visit, clears physical table occupancy and writes an audit event
in one database transaction. It requires ALL noncancelled visit orders to
have independent immutable cash-only finance attestations (Upgrade 113),
and guest departure, cleaning and shisha pickup to be complete (112).
It rejects ambiguous visits, zero paid orders, and cancelled orders
with payment evidence. Attested orders remain immutable.

**Not supported:** mixed payments, credit, online provider payments,
owner waivers, correction/refund cases, unlinked legacy orders, and
reservation conflict remediation. Do not enable general checkout via
this limited RPC. Before production deployment, reconcile the complete
deployed schema, table-state triggers, concurrent order insertion paths,
and reservations; run transaction and adversarial concurrency tests.

ZIP verified only. No Supabase execution or Flutter compilation.
