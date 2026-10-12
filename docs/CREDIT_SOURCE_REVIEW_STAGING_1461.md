# Upgrade 1461 — Credit source review before debit

Adds a permission-controlled server review RPC and displays the authoritative motel invoice UUID and IQD charge amount before employee confirmation. The original posting RPC must independently revalidate under transaction locks. This review is not a payment confirmation.

## Staging release gate

1. Apply migrations in order to an isolated staging Supabase project; do not use production data.
2. Compile Flutter with `GS_ENABLE_VERIFIED_CREDIT_POSTING=false` first; assert charge button is disabled.
3. Test unauthorized and expired sessions, pending/nonpending requests, mismatched invoice lines, revoked barcode links, cash collisions, already charged invoices and duplicate drafts.
4. Confirm displayed invoice and IQD amount match source rows, then confirm the posting RPC rejects records changed between review and posting.
5. Test concurrent duplicate taps, concurrent clients, timeout/retry, idempotency and rollback. Confirm exactly one charge, matching journal/account balance and invoice link.
6. Do not enable the posting flag outside staging until the entire chain passes and the owner approves.
7. No prepaid allocation, invoice-paid transition, numeric café-order crosswalk, unified-ledger settlement or certified Dashboard totals are provided by this upgrade.

No live tests were executed as part of archive generation.
