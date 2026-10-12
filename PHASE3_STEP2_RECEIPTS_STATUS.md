# Phase 3 — Cash receipts (source update)

- Added a read-only per-order cash receipt list to Payments Management.
- Receipts represent only previously recorded cash ledger entries, not card/credit payments or fiscal tax invoices.
- Uses server-side authorization and existing payment reference/employee/time audit fields.
- Deploy migrations through 023 in order before using the screen.
- No PDF/printable receipt, tax invoice, payment reversal, card processing, or payment lifecycle completion is claimed.
- Flutter compilation and live Supabase integration remain unverified.
- Historical implementation estimate: 61%; no independently measured change.
