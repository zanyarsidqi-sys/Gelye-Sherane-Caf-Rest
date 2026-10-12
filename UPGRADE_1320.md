# Upgrade 1320: Dashboard + linked Payments Management

- Dashboard recorded-cash card points to receipt-ID validation.
- Payments receipt IDs are checked for duplicates after text sanitization and case-folding, preventing differently capitalized IDs from being treated as distinct receipts in the same response.
- Payments ledger order status and displayed order ID are sanitized as untrusted backend text, preventing control-character line injection in the list.
- Existing Supabase RPCs, navigation, permission checks and other files preserved.
- Static assertions and archive checks performed; Flutter compilation, device tests, and live Supabase checks NOT performed.
