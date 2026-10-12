# Upgrade 316 — Notification hub / customer calls integration

- Replaced the Notifications section placeholder with the existing customer-assistance staff queue.
- Both Notifications and Table Orders use `gs_staff_customer_call_queue` and `gs_staff_update_customer_call`; no second source of truth.
- Server RPC checks Table Orders view permission, and status changes require Table Orders edit permission (migration 315).
- Queue refreshes every 8 seconds only while its screen is open; this is **not** background push notification delivery.
- When the queue RPC cannot be accessed, the Notifications screen fails closed and offers Retry.

## Remaining verification
Run Flutter analyzer and integration tests, apply Supabase migrations in order, verify read-only/edit roles, and test across iOS, Windows and web. Background push delivery remains unimplemented.
