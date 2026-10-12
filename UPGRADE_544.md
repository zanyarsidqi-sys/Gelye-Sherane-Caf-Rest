# Upgrade 544 — Kitchen receipt integrity

- Kitchen staff cannot acknowledge a failed revision dispatch until an authorized retry requeues it.
- Flutter hides acknowledgment on failed and acknowledged revisions, and displays an actionable failure message.
- Database RPC enforces the rule under row lock, independently of client state.
- Financial pricing and existing invoice logic unchanged.

## Verification
Archive integrity and static checks only. Flutter SDK and live Supabase are unavailable; compile and migration execution not verified.
