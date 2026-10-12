# Dashboard coding upgrade 04 — unverified
- Added reusable required guest-count / optional per-person name Flutter input component.
- Added customer metric cards, shown ONLY if authorized dashboard RPC supplies actual numeric fields.
- No invented customer totals; current RPC may not yet return customers_today or tourism_customers.
- Guest entry widget is not yet connected to table order persistence or individual payment ledger.
- Live floor-plan map and detailed per-person split payment remain pending.
- No Flutter build, tests, database migration or Supabase verification performed.
