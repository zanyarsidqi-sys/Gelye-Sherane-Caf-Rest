# Upgrade 1195 — Customer call/service task synchronization

- Expands the existing visit-validated customer call RPC to accept `pick_dishes` and `clean_table`, correcting a prerequisite missed in 1194.
- Synchronizes completed/cancelled customer calls and their linked service tasks in either direction, with status guards to avoid loops.
- Task assignment/acceptance moves a waiting customer call to accepted.
- All writes occur in the same database transaction.
- The original QR visit validation, rate limiting and duplicate active-call checks are retained.
- Existing calls without a linked task remain unaffected.

**Deployment note:** Flutter compilation and live Supabase migration tests remain deferred. Verify actual PostgreSQL trigger ordering, customer QR call flows, RLS, and rollback in staging before production.
