# Upgrade 1313 — Dashboard ↔ Payments receipt safety

- Dashboard recorded-cash card explicitly invites receipt review while retaining its existing payments_management route and metric key.
- Payments reconciliation RPC rejects unexpected shapes and responses above its 200-order request cap.
- Receipt RPC rejects unexpected shapes and excessively large lists.
- Invalid/nonpositive receipt amounts are labeled invalid and cannot be copied as valid receipts.
- Receipt fetch errors no longer expose raw backend exception text to employees.
- Static assertions and ZIP byte-preservation checks passed. Flutter/Dart compilation and live Supabase/device tests not available.
