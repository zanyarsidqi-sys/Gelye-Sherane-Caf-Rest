# Upgrade 241 — Admin bill-discount invoice quote (read-only)

Adds `gs_admin_bill_discount_invoice_quote` and a Flutter **Invoice quote** button in the Admin Bill Discount dialog. It retrieves the latest approved draft, checks that current item totals still match the approval, enforces explicit discount stacking approval, and blocks known recorded payment/settlement rows. For existing ledgers without an `order_id` column it fails closed instead of assuming unpaid.

**Not implemented:** Posting the discounted amount to authoritative settlement/invoice records, generating printable final bills, credit/partial-payment reconciliation, SUNMI printer drivers. This conservative read-only stage avoids mischarging customers until all financial ledgers are reconciled. Migration needs staging verification. Flutter compile and live Supabase tests not run.
