# Upgrade 114 — Protect approved cash-only settlement

Implemented database mutation guards for **cash-only settlement-attested orders**.
Once finance attests an eligible order, subsequent changes to that order,
its line items, cash receipts, unified ledger entries, accounting corrections,
external payment evidence or owner complimentary offers are rejected.
Child writes lock the parent order row to serialize against attestation.

This protects the attestation from later edits; it does **not** attest
mixed-method payments, verify physical refunds, release tables, or mark
checkout complete. Existing transfer paths are still disabled.

**Deployment caution:** review all existing order/payment triggers and run
concurrent-transaction tests before deploying. SQL has not been run against
Supabase and Flutter has not been compiled. ZIP CRC only.
