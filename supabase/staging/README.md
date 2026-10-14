# Staging bootstrap and Release 1.0.0.13 Tables consolidation

This bootstrap is restricted to Supabase staging project `kuibukbtdbvaswgfcfgv`.
It is not a production migration. The baseline is a schema-only snapshot of the
production `public` schema; it contains no café rows and does not create or alter
Supabase-managed `auth`, `storage`, or extension schemas.

The original bootstrap files and staging-only version IDs are in
`1.0.0.12-menu-migration-map.json`. The 1.0.0.13 catalog-only migration is
mapped in `1.0.0.13-tables-migration-map.json` and implemented in
`supabase/migrations/20261014170000_tables_orders_merge.sql`. The generated SQL installer is kept under
`generated-artifacts/gelye-staging-1.0.0.12/schema/` and must be run only after
checking that the target ref matches and its public schema and migration ledger
are empty.

The production export's default-privilege statements are intentionally omitted:
staging's existing default ACLs were checked against them and already match.
The staging database role cannot change defaults owned by Supabase-managed
roles, and no default-privilege change is needed.

Do not bulk-run the repository's legacy migration directory. It contains
duplicate and conflicting variants; this bootstrap applies only the verified
Menu prerequisites and Menu migration listed in the map. It leaves all other
feature migrations unrecorded.

The Menu approval policy is owner-only. The staging Menu migrations permit the
`owner` profile role in addition to existing admin, manager, and employee roles;
they do not assign that role to any account.

The original bootstrap seeded 35 verified management-section catalog rows.
Release 1.0.0.13 removes only the duplicate top-level `table_orders` catalog
row, leaving 34 sections. The separate employee permission row remains intact
for protected order actions. No employee, customer, order, payment, inventory,
or other operational records are copied or modified.

Release 1.0.0.14 groups Cost, Revenue, Invoices & Payments, Discount
Management, Credit Management, and Payment Management under one visible
Payment Management entry, leaving 29 top-level sections. The staging migration
removes only the five duplicate catalog rows, keeps the `payments_management`
catalog key, and verifies that all employee permission grants are unchanged.
Each nested finance view still checks its original section permission. No
employee, customer, cost, invoice, discount, credit, order, payment, inventory,
or other operational records are copied or modified.
