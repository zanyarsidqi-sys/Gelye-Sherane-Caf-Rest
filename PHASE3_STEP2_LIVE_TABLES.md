# Phase 3: Live Tables
Replaced local-only 20-table preview with Supabase-backed occupancy and pricing mode. No fictional tables are seeded.
Run migration `20261009_016_live_tables.sql` after foundation; configure real tables with authorized SQL/admin workflow.
Existing order creation remains separate and does not yet enforce occupancy/mode from gs_cafe_tables; do not claim pricing linkage is complete.
Status: source implemented; Flutter compilation, database deployment, RLS and concurrent-user tests pending.
Overall project completion: last planning estimate 60%; no defensible recalculation without weighted 35-section audit.
