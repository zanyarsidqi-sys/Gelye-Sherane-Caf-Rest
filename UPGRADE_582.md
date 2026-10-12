# Upgrade 582 — Kitchen queue pagination (Sections 03–05 integration)

- Removed the live Kitchen panel's silent 100-order limit, which could hide older active orders from kitchen staff.
- Added deterministic, bounded server-side pagination (500 orders per page, up to 5,000 records).
- Added explicit warnings when the safety cap is reached, including when local filters match no loaded records.
- Preserved server-side permission checks and the existing kitchen status RPC.

## Verification
Static regression tests are in `tests/integration/test_upgrade_582_kitchen_pagination.py`.
Flutter compilation and live Supabase tests are still required. A production queue should eventually use server-filtered active-order pagination and real-time updates rather than loading thousands of orders.
