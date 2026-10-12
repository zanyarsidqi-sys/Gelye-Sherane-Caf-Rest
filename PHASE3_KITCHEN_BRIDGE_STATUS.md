# Phase 3 — Accepted public orders → kitchen queue

Implemented in source: SQL migration 012 links accepted public order requests to actual gs_orders and gs_order_items, in the same transaction as staff acceptance. It preserves the public order item price snapshot, checks the request total, prevents duplicate acceptance through a locked pending-status check and a unique request link, and writes existing staff review audit records. The existing LiveKitchenPanel can show the resulting gs_orders and advance their kitchen status via migration 002.

Deployment: review and apply SQL migrations in dependency order; check 010 capacity triggers, 011 validation, and permissions. Test acceptance/decline, concurrent acceptance, kitchen visibility, price snapshot, and status transitions against a staging Supabase project. No live database or Flutter build test has been run. Public edge rate limiting/CAPTCHA remain launch blockers.

Progress: ~60% implementation estimate carried forward; not a measured percentage. 35 section-level production verifications remain.
