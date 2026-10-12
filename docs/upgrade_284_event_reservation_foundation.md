# Upgrade 284 — Event reservation foundation

Added migration `20261010_284_event_reservation_foundation.sql` with event request records, advance product quantities, review audit storage, staff request RPC and staff product-request RPC. All tables have RLS enabled and direct anonymous/authenticated table access revoked.

**Important boundaries:** This is a backend foundation only. Customer public submission, CAPTCHA/rate limiting, staff/customer Flutter forms, Admin approval/rejection RPC, event/ordinary-table booking conflict locking, product catalog binding, price snapshots, payments, kitchen ticket scheduling, and live tests remain outstanding. The `gs_event_review_audit` table is reserved for future admin workflow. Rental quotes cannot be set by the requester through these RPCs. Pending events do not trigger kitchen work or charges.

All times are stored as `timestamptz`; render with `Asia/Baghdad` in Flutter. Currency amounts use integer IQD.
