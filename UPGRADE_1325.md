# Upgrade 1325: Financial Overview & Payments card register

- Added 12 requested financial Dashboard cards. Cards show verified numeric RPC values only; missing values explicitly show Not available, not zero.
- Every new card opens existing View Details and the permission-gated Payments Management navigation.
- Linked Payments Management now lists all 12 report areas and explains missing secure backend data, time-range and employee-filter requirements.
- Existing cash-only ledger, date shortcuts, branding, receipts, and unrelated project files preserved.
- Future work: authoritative accounting definitions, SQL migrations and RLS, range/user report RPCs, detailed records, refund/cash handover workflows, compilation and device tests.
- This is a source-code integration increment, NOT full financial-feature completion.
