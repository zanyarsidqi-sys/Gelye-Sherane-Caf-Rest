# Dashboard Upgrade 129 — Real electronic verification inbox UI

This increment advances electronic payments without falsely certifying them.

- Adds a dedicated responsive Flutter **Electronic payment verification** screen.
- Uses the existing permission-checked Supabase
  `gs_dashboard_payment_verification_queue` RPC from Upgrade 66.
- Connects it to the existing **Payment confirmations** screen.
- Displays provider, order, expected and reported IQD, mismatch flags,
  verification intake status, and the evidence ID.
- No fake **Confirm Paid** button: staff cannot forge provider confirmation.
- Does not alter credit balances, financial ledger, or table release.

**Still needed for real electronic settlement:** signed provider webhook
verification, idempotent authoritative payment posting, refunds and
reconciliation, followed by settlement attestation and checkout integration.

ZIP CRC and source assertions verified. Flutter not compiled and Supabase
RPC not executed against the user's database.
