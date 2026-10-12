# Upgrade 315 — Customer assistance permission boundary

- Added `20261010_315_customer_call_edit_permission.sql` to require `table_orders.can_edit` for employee call state changes; queue viewing still requires `can_view`.
- Preserved row locking, valid state transitions, assigned-employee restrictions and the staff audit insertion from Upgrade 311.
- Added a staff permission check RPC and read-only queue notice. Buttons are disabled when the user lacks edit permission or the permission check fails.
- Apply migrations in order. This migration must run after 311; staff without `can_edit` will no longer be able to claim or complete calls.
- Pending: Flutter compilation, actual Supabase migration execution, authenticated role tests, realtime/background push notifications.
