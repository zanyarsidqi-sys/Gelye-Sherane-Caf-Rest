# Upgrade 472 — Dashboard permission scoping correction

## Fixed
Migration 471 returned counts for tables, motel orders and kitchen regardless of those sections’ view permissions. Migration 472 replaces that RPC with explicit permission-scoped aggregates. Missing metrics are **omitted**, not returned as zero. UI shows **Restricted** rather than a misleading zero. Date range uses explicit Asia/Baghdad midnight bounds. Financial numbers remain excluded.

## Required live verification
Apply migrations through 472 in order, test authenticated users with Dashboard-only, Dashboard+Tables, Dashboard+Kitchen, Dashboard+Table Orders and Dashboard+Motel Orders permissions, and test denied/anonymous requests. Confirm time boundaries, order statuses, and iPhone/Windows layout. `flutter analyze` and live Supabase tests were not run here.

## Previous sections
Dashboard: reassessment ongoing (not verified above 90%); Tables: 94% historical estimate; Table Orders: 69% historical estimate; Motel Orders: 91% development estimate. None certified 100%.
