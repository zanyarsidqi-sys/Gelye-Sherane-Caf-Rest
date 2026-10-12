# Phase 3 / Step 2 — Cart integrity hardening

This incremental update adds migration 020 to harden the atomic cart RPC from migration 019.

- Reject duplicate product IDs in a single cart (instead of charging unexpected duplicate lines).
- Reject null or negative mode-specific selling prices.
- Validate all cart lines before inserting the order; PostgreSQL transactions still roll back on any failure.
- Keep authorization, table occupancy lock, server-side Normal/Tourism selection, and Motel Tourism enforcement.

Deployment: apply SQL migrations through 020 in order to a staging Supabase project, then test authenticated/unauthorized users, normal/tourism table orders, motel orders, invalid prices, duplicate lines, concurrency, and transaction rollback. No live deployment or Flutter compile has been performed.

Progress: previous overall estimate 60%; this safety change does not justify a newly calculated percentage. Step 2 remains incomplete. Payment collection and reconciliation are NOT implemented by this update.
