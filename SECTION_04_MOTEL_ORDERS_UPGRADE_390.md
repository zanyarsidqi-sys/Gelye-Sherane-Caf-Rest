# Upgrade 390 — Payment Draft Integrity

Adds an authorized, read-only RPC to validate existing payment drafts against current finance invoice totals, unpaid state, and source reconciliation. Adds an employee check action next to each payment draft. Does not settle or move money.

Migration: `supabase/migrations/20261010_390_motel_payment_draft_integrity.sql`

Testing: ZIP integrity checked. Flutter CLI and live Supabase migrations not tested. Section 04 progress remains 82% estimated.
