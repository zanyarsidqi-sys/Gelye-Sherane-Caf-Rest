# Upgrade 305 — Specific order and extra chairs
- Customer QR menu now has a visible Extra chairs / specific order entry.
- Customer assistance form includes two new request types: specific order (requires details) and extra chairs (1–10 chairs).
- Requests reuse existing table-visit session validation, staff queue and request status lifecycle.
- Database migration extends call-type constraint and RPC validation, retaining one active request per type per visit.
- These are **staff assistance requests**, not automatically billed product orders or guaranteed chair reservations. Staff must verify chair availability and create a real order through authorized ordering flow.
- No live Supabase migration or Flutter compilation performed; schema compatibility requires validation before deployment.
