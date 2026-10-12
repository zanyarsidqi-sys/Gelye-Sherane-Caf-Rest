# Upgrade 1240 — Cross-section source safety corrections

## Concrete defects corrected
1. `StationTicketFormatter` used double-escaped Dart raw-string regex character classes (`\\x00`, `\\s+`), which did not reliably sanitize printer control characters and whitespace. Corrected to Dart raw regex escape sequences; added empty-product, quantity and output-size guards.
2. `GelyeOfficialInvoiceLayout` required a `total` key while `GelyeA4OfficialInvoiceTemplate.build` actually produces `total_minor`. Unified the validation contract, added A4 structure checks. This is still an A4 data model, **not a PDF**.
3. Added client-side identity, queue-kind, request-key and explanation length validation to supervisor print-review submissions; **database authorization remains authoritative**.
4. Tightened invoice line quantity and issue-date sanity checks. Both print formats remain read-only and do not initiate payments.
5. Added `tool/verify_upgrade_1240.py` static assertions for the mismatched A4 field and regex regression.

## Remaining risks
- No Flutter compilation, Supabase migration execution, integration testing or physical printer testing performed.
- Invoice renderer is not yet wired to authoritative finance invoice retrieval; A4 PDF and hardware driver still outstanding.
- Station print review and correction workflows need live RLS, RPC signatures, and transaction tests.
- Manual print outcome checks cannot guarantee physical delivery; never auto-reprint UNKNOWN outcomes.
- Full UI previews and section approval remain outstanding.
