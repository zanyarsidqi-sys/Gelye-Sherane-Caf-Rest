# Upgrade 260: pre-delivery editing safety foundation

- The employee Order Board now identifies delivered items as locked.
- Pre-delivery items show an editing requirements control.
- No unguarded client-side update or direct SQL mutation has been introduced.
- Pending implementation: audited Supabase RPC with optimistic concurrency, financial recalculation, preparation-ticket revision/acknowledgment, and role checks.
- This upgrade does NOT enable editing, customer submission, or live synchronization.
