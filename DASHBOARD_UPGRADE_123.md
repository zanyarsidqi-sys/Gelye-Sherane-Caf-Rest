# Upgrade 123 — Cash-only settlement integration defect fixed

**Root cause:** Upgrade 113 rejected any unified-ledger entry. But earlier
migrations (75/83) allow an *authoritatively linked mirror* of a legacy cash
receipt in the unified ledger. Such a mirror is the SAME cash payment,
not a second payment method. Rejecting all ledger entries meant legitimate
reconciled cash-only orders could never be attested/released.

**Fix:** Replace the two existing RPCs, not add a new readiness workflow.
They now allow a ledger entry **only** when linked through the private,
immutable `gs_cash_ledger_reconciliation_links` table to a same-order
receipt with identical amount, `entry_type='cash'`, `direction='credit'`,
and `source_system='legacy_cash'`. Any unmatched, additional, mismatched,
credit, refund or provider ledger entry still blocks cash-only approval.

The cash receipt sum remains authoritative and mirrored entries are
**never double counted**. Physical departure/cleaning and independent
finance approval rules remain unchanged.

Static verification only. Supabase deployment, schema checks, and
concurrent settlement tests are still mandatory before production use.
