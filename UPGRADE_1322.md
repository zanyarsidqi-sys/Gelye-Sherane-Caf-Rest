# Upgrade 1322 — Dashboard / Payments receipt recovery

Project: Gelye Sherane Restaurant

- Dashboard recorded-cash card now points employees toward retryable receipt review in Payments Management.
- When a receipt RPC fails or times out, the Payments section presents an actionable Retry receipts SnackBar for the *same selected order*, avoiding re-selection.
- Retry reuses the existing `_showReceipts` path, so order ID validation, RPC timeout, response-shape checks, duplicate-ID detection and copy safeguards still apply.
- Existing ledger refresh/retry, navigation, permission checks and Supabase RPC identifiers remain unchanged.

Verification: archive CRC integrity, byte-preservation of unrelated entries, and static source assertions. Flutter/Dart compilation and live Supabase tests unavailable here.
