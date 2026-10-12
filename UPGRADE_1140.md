# Upgrade 1140 — Kitchen order identifier validation

Fixed a crash when PostgREST serializes bigint kitchen order IDs as numeric strings. Sorting and order-action rendering now use a validated positive integer parser; malformed IDs are shown as invalid and cannot be advanced.

## Section 05 progress measurements
- Kitchen source component presence: 4/4 (100%, unchanged).
- Five runtime acceptance areas verified: 0/5 (0%, unchanged). This is a **verification percentage**, not a statement that functionality is 0% implemented.
- New targeted source regression tests: 3/3 passed.
- Functional completion percentage: unknown pending Flutter and live Supabase testing.
