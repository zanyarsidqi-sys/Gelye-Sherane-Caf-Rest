# Upgrade 1239 — Kitchen / Table Orders / Finance boundary review

Source changes:
- Hardened POS receipt text against control-character/newline injection in company, invoice, line-item and payment-status fields.
- Validates payment status is nonempty.
- Hardened kitchen ticket validation before passing data to a printer adapter.
- Added a read-only invoice print boundary requiring explicit finalized status and authoritative invoice ID/number agreement. The same immutable invoice object can be rendered into POS text or A4 structured data. No invoice creation, payment capture or credit debit occurs during formatting.

Unresolved integration risks:
- The finance screen does NOT yet load finalized invoice snapshots into the new print boundary. No real A4 PDF generator, printer transport or official tax validation exists.
- Station print revisions still require end-to-end test with the real database schema and physical devices.
- Invoice line sums may differ from totals due to discounts/tax; do not infer or recompute totals from ticket items.
- POS receipt rendering is plain text, not a hardware driver.
- Flutter compilation, Supabase migrations and physical printer testing are deferred.
