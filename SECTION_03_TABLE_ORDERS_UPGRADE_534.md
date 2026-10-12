# Upgrade 534 — Order board pagination boundary validation

- Recheck the last page after loading to detect changes at the queue tail during offset pagination.
- Compare all returned tail row fields; fail closed if the tail differs.
- Expand the first-page comparison to include order ID, product name, and stored unit price.
- Keep all previous migrations and modules unchanged.

Limitations: this is not a transactionally consistent database snapshot. Flutter compilation and live Supabase testing are still required.
