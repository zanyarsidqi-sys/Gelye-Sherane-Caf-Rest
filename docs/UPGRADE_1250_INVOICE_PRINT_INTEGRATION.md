# Upgrade 1250 — Invoice print boundary and Kitchen integration review

## Source changes
- Added `GelyeFinalizedInvoicePrintAdapter`: one immutable finalized Finance invoice snapshot creates both POS receipt text and an A4 layout map, with identical invoice ID/number and no payment writes.
- Rejects non-finalized invoices and invalid document data. Makes a defensive copy of invoice lines.
- Existing `GelyeInvoicePrintBoundary` still requires a trusted finalized invoice identity; this adapter **does not fetch invoices** or prove caller authorization. A production Finance RPC must return an authorized finalized snapshot.

## Reviewed existing source
- `lib/shared/live_kitchen_panel.dart` has `gsKitchenGuestDisplay` with a safe guest-number fallback; live UI needs runtime checks for data availability and station scoping.
- `lib/services/station_print_worker.dart` prints station, table and customer labels from ticket snapshots; unknown printer outcomes must remain under manual review, not automatic retry.
- `lib/shared/gelye_invoice_templates.dart` provides POS text and structured A4 data. **No PDF renderer or ESC/POS driver is implemented here.**
- Station management remains in Section 05 Kitchen. Kitchen tickets are not financial invoices; do not derive invoice totals from them.

## Remaining before production
1. Integrate authenticated, RLS/permission-checked Finance finalized-invoice read RPC and verify snapshot completeness and taxes/discounts; do not trust client-supplied `isFinalized`.
2. Wire invoice print action into authorized Table Orders/Finance UI with reprint audit, and connect actual A4 PDF and POS printer drivers.
3. Validate station routing and supervisor permissions with staging Supabase and real devices.
4. Run Flutter analyzer/tests, migration tests and physical printer tests when available.

No live tests, database deployment or physical printing performed in Upgrade 1250.
