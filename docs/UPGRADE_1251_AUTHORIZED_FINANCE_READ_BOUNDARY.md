# Upgrade 1251 — authorized read-only Finance invoice boundary

## Implemented
- Added a permission-gated `SECURITY DEFINER` RPC to retrieve existing posted motel-food Finance invoice records and their item amounts. Checks both Finance and Motel viewing permissions and reconciles line count and total before returning data.
- Added a Flutter Supabase reader mapping the RPC response to the existing invoice-print adapter snapshot type.
- **Fail closed:** existing `gs_motel_food_finance_invoices` records are explicitly `unpaid` and lack an authoritative finalization/settlement proof. The RPC always returns `is_finalized=false`; the print adapter rejects printing them. No fake finalized status, no duplicate payment or invoice write.

## Not completed / deployment blockers
- Identify and implement the actual finalized Finance invoice source and its authorization, settlement proof, invoice number, immutable lines and audit history. Wire the reader to that source only after the Finance data contract is established.
- Confirm whether a posted/unpaid invoice may be issued as a legally valid invoice; do not equate invoice issue with payment. Current print adapter requires finalized status.
- End-to-end Kitchen, station routing, print and PDF output integration remains unverified. No A4 PDF renderer is included.
- No Flutter compilation, live Supabase migration/RLS verification or physical printer testing was performed, per request.
