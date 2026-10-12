# Upgrade 389 — Payment Draft Review and Cancellation

- Finance Handoff lists prepared payment drafts with method, amount, and status.
- Authorized employees can cancel active drafts with a required reason; cancelled records retain author and timestamp.
- Partial unique index permits a new draft after cancellation, but only one active draft per invoice.
- Each preparation attempt uses a fresh UUID; the database prevents replay of cancelled attempt IDs.
- No money moves; no invoice marked paid; no credit debits.
- Migration must be applied before the new Flutter UI is used.
- Flutter compilation and live Supabase integration were not available in this environment.
