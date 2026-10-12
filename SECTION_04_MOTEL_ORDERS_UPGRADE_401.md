# Upgrade 401 — Credit payment readiness gate

Adds a read-only, permission-gated RPC for motel food **credit** drafts and a Credit Readiness action in the employee finance interface. Verifies active draft, unpaid invoice, amount, source mapping and allocation plan. Always reports that actual credit account/barcode verification and idempotent balance debit remain outstanding. **No credit deduction or invoice settlement occurs.**

Credit backend integration, shared ledger integration, electronic settlement, and reversals remain pending. Flutter compilation and live Supabase execution were not available. Apply the migration and test in a staging database before production use.
