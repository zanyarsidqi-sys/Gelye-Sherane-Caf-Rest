# Upgrade 528 — Block quantity corrections after payment evidence exists

The authenticated, audited `gs_correct_unaccepted_table_item_quantity` function now checks item payment allocations, legacy cash payments, unified ledger entries and external payment evidence for the parent order while holding its order row lock. Corrections are rejected if any such evidence exists, rather than silently changing the amount after payment. Existing permissions, kitchen ticket and invoice checks, expected-quantity concurrency, employee reason, audit revisions and notification dispatch remain intact.

**Deployment:** Apply migration `20261010_528_quantity_payment_reconciliation_guard.sql` after Upgrade 527. No Flutter UI change; Supabase error is surfaced through existing correction handling. A dedicated financial reconciliation workflow is still needed to allow supervised post-payment changes.

**Verification:** ZIP archive integrity checked; Flutter compilation and live Supabase migration/function testing not performed.
