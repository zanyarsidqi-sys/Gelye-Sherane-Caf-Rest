# Upgrade 690 — Inventory bigint normalization

- Normalize PostgreSQL bigint stock quantities from either integer JSON values or decimal-string representations.
- Reject malformed, negative, fractional, or absent quantities rather than silently misclassifying inventory.
- Use normalized exact integer values for out-of-stock counters and filters.
- Scope: Section 07 Products & Inventory. No database migration.
- Verification: static regression tests; Flutter compilation and Supabase integration remain untested.
