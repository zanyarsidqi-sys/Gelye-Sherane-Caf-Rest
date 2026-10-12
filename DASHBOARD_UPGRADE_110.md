# Upgrade 110 — Physical checkout completion integration

A concrete visit-scoped Supabase RPC `gs_visit_physical_checkout_status`
now computes the physical side of checkout from the actual departure record,
noncancelled cleaning tasks, and shisha tasks. It requires all required
tasks to be complete and returns a precise blocker for staff.

This is **not** a release RPC: `physical_ready` is explicitly NOT
`checkout_allowed`. No tables are released or marked available. A separate
authoritative financial settlement mechanism is required and is not present
in the project. Claiming fully functional checkout at this point would be
unsafe, especially with unverified provider payments and physical refunds.

Static ZIP verification only. SQL not deployed or tested against Supabase.
