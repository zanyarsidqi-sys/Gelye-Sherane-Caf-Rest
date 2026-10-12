# Upgrade 520 — complete paginated board integration

Table Orders now retrieves permission-scoped pages of up to 250 rows, validates all rows and IDs, and fails closed if more than 5000 rows exist or any page fails. Manual handoff requires a fully loaded board. Depends on Upgrade 519 migration. Live Flutter/Supabase testing still required.
