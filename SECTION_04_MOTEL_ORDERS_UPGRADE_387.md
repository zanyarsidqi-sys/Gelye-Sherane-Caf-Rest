# Upgrade 387 — Read-only Payment Eligibility

Adds a Supabase security-definer RPC `gs_staff_motel_food_payment_eligibility` that checks authorized access, posted invoice source reconciliation, and unpaid status. The employee finance handoff UI exposes a read-only payment eligibility dialog for each posted invoice. No payment posting, settlement, credit deduction, or unified invoice mutation is implemented.

Verification: ZIP integrity and static presence checks only; Flutter CLI and live Supabase migration tests not run. Section 04 progress remains **80% estimated**.
