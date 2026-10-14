# Release 1.0.0.12 Menu staging bootstrap

This bootstrap is restricted to Supabase staging project `kuibukbtdbvaswgfcfgv`.
It is not a production migration. The baseline is a schema-only snapshot of the
production `public` schema; it contains no café rows and does not create or alter
Supabase-managed `auth`, `storage`, or extension schemas.

The exact mapped source files and staging-only version IDs are in
`1.0.0.12-menu-migration-map.json`. The generated SQL installer is kept under
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

Only the 35 verified management-section catalog rows are seeded. Employee,
customer, order, payment, inventory, and other operational records are not
copied from production.
