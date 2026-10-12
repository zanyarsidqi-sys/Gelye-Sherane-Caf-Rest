# Upgrade 1317 — Dashboard + linked Payments Management

- Dashboard recorded-cash card directs staff to the validated ledger.
- Payments Management formats whole-IQD amounts with thousands separators; invalid values remain unavailable.
- Cash payment entry counts are validated as nonnegative whole numbers before display.
- Navigation and RPC identifiers retained; no changes to database schemas or unrelated sections.
- Static source and ZIP preservation checks performed; Flutter build and Supabase integration not executed.
