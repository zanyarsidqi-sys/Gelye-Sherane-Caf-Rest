# Upgrade 386 — Posted Food Finance Invoice Source-Line Drilldown

- Adds a permission-checked, read-only Supabase RPC for posted finance invoice source lines.
- Shows source order, source register line, stored amount, original order amount, and delivered status.
- Marks source lines requiring review if their order, guest stay, room, amount, or register reference differs.
- Adds a source-line details button to each posted invoice in the finance handoff panel.
- No unified invoice posting, payment collection, credit deduction, or accommodation billing.
- Flutter compilation and live Supabase migration were not run in this environment.
- Section 04 estimated progress remains 80% (review tooling, not new payment capability).
