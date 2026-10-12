# Dashboard Upgrade 50 — Table Visit / Session Foundation

**Added**: Draft `gs_table_visits` identity table with one open visit per table,
server-side read-only Dashboard RPC, and nullable visit foreign keys for
orders, service tasks and owner complimentary offers.

**Safety**: Historical orders are NOT assigned to the newest visit by table
number. No public direct write grants or new session creation RPC. The schema
must be integrated atomically with the existing table occupancy and order
creation functions before use. Session IDs do not yet affect payment,
cleaning, or table release checks.

**Remaining**: transactional visit opening, explicit order binding, verified
multi-method payment settlement, owner-verified complimentary postings,
cleaning task binding, release and visit close audit, permission review,
Flutter build and live Supabase tests. The legacy table-number checks still
exist and must be replaced before production deployment.

This is an additive draft; not deployed or runtime tested.
