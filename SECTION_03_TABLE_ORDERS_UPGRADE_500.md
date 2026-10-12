# Upgrade 500 — Table Orders authorization-safe reloads

- Reassessed the two staff-only Table Orders operational queues (service jobs and per-item fulfillment board).
- Clear previously loaded authorized rows when a refresh begins or fails, avoiding stale or previously authorized customer/order details remaining visible after an RPC failure or permissions change.
- Prevent service-job actions while a queue is loading or has failed.
- Validate order-item IDs before advancing fulfillment and disable actions on invalid IDs, loading or failed board states.
- Disable item timeline and order-history actions while data is being refreshed or unavailable.
- Distinguish loading, empty, and unavailable queue states in the UI.
- Preserve existing server-enforced RPC authorization, item status transitions, and all other project files.

Outstanding Section 03 work includes real-device UI verification, secure editing and station-ticket reconciliation, customer flows, Supabase permissions and end-to-end tests. The historical 69% estimate is not re-certified by this patch.

Verification: archive integrity and duplicate path validation. Flutter compilation and live Supabase tests not run.
