# Upgrade 240 — Admin Bill Discount Draft

Adds an Admin-only bill-discount preview and audited approval draft. Percentage or fixed IQD off the current order total; explicit opt-in for stacking on item discounts. Blocks orders with cash receipts or cash-only settlement attestations. Does NOT alter existing financial ledgers, totals, or printed bills; this is intentional until authoritative settlement integration is implemented and verified.

Files: new migration `20261010_240_admin_bill_discount_draft.sql`; Flutter Tables toolbar dialog. Apply migration in staging after all preceding migrations. Physical printing, bill finalization integration, other payment-ledger checks, Flutter compile and live Supabase tests remain pending.
