# Upgrade 413 — Pending Credit Account Registration and Barcode Linking

Added a Credit Management screen for registering customer/account references and linking existing barcode registry records. Both accounts and links remain pending; credit limit and outstanding balance default to zero. The barcode registry account reference must exactly match the pending account reference. Server-side Credit Management edit permissions are enforced. Audit entries record account registration and barcode linking with employee identity and timestamp. Existing CreditBarcodePanel remains accessible.

No account ownership verification, credit approval, credit limit change, ledger posting, debit, or settlement is implemented. Migration `20261010_413_credit_account_registration.sql` must be applied in order. Flutter build and live Supabase migration have not been tested.
