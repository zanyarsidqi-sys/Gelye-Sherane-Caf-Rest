# Upgrade 388 — Payment preparation drafts

Introduces an isolated, non-settling payment-intent draft for posted motel-food finance invoices. Staff can choose cash, credit or electronic as an intended method. A database transaction locks the invoice, reconciles source lines, and enforces one draft per invoice. Duplicate retries using the same invoice UUID and method are idempotent; a conflicting method is rejected. There is no payment processor call, cash ledger write, credit debit, paid-status update, or unified accounting posting.

Migration: `20261010_388_motel_food_payment_intent_draft.sql`. Employee UI: `lib/shared/motel_food_finance_handoff_panel.dart`.

Not validated with Flutter CLI or a live Supabase database. Next: implement explicit draft cancellation/change with audit and integration to a verified shared payment ledger, only after testing financial schema and permissions.
