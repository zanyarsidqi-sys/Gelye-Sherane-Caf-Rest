# Upgrade 396 — UUID-native payment allocation review plan

Adds a restricted, idempotent allocation-review plan tied to a motel payment draft, UUID finance invoice and verified source bridge. The employee interface offers **Allocation Plan** for active drafts.

**No actual payment is processed.** The legacy `gs_orders` bigint ledger remains unlinked. No credit debit, cash collection, electronic settlement, invoice payment status change, or unified ledger write occurs. Cancelled drafts cannot create new plans; previously prepared plans remain audit records and must not be interpreted as payable.

Migration: `supabase/migrations/20261010_396_motel_uuid_allocation_review_plan.sql`. Requires prior migrations through 395. Flutter and live Supabase not executed here.

Section 04 estimated progress: 85% (not production verified).
