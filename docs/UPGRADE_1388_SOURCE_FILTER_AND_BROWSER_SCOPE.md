# Upgrade 1388: verified Standing Cash eligibility filter

- Added a switch to show only orders explicitly marked `cash_collection_eligible == true` by `gs_standing_cash_active_orders`.
- Applies before filtered record count and cash-only sample sum; clearing filters resets the switch.
- Pending Payment keeps its separate source-status filter, posted-invoice-only totals, disabled Pay action, and read-only invoice details.
- Standing Cash keeps server-authorized Pay and itemized More Details.
- No changes to app shell, section routes, Cash Reconciliation, Supabase migrations, or permission checks.
- Browser system switching between independently deployed projects is a preview/container responsibility, not something safely implemented by adding a cross-project route to one Flutter application.
- Static verification only. Flutter build, runtime tests, 35-route audit, and screenshot matching still required.
