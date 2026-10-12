# Dashboard Upgrade 105 — Cash correction visible in Flutter

Changed the existing **Cash reconciliation** Flutter screen, rather than
adding another SQL approval/readiness stage.

- Tap an order to open a real Supabase-backed financial detail dialog.
- The dialog calls `gs_dashboard_payment_reconciliation_summary`, which
  Upgrade 104 updated to include posted cash accounting corrections.
- Displays adjusted cash, matched/unmatched cash, nonmirrored ledger net,
  provisional balance, reconciliation exception count and backend warning.
- Errors are shown without exposing raw database exception details.
- Read-only by design: does not refund cash, approve settlement, move a bill
  or release a table. Backend permissions remain authoritative.

**Example:** 50,000 IQD original cash with a posted -10,000 IQD correction
shows 40,000 IQD adjusted provisional cash, plus an exception requiring
independent physical-refund verification.

Testing: ZIP CRC and static source checks only. Flutter not compiled;
Supabase RPC not deployed or executed in this environment.
