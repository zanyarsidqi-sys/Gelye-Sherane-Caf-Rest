# Upgrade 1145 — Kitchen readiness verification

## Change
Added `supabase/verification/kitchen_1145_readiness.sql`, a read-only eight-check database readiness report for the kitchen status RPC, order tables, served-item trigger, and execution privileges. This is **not** a migration and does not change production data.

## Runbook
1. Back up the staging database. Review/apply migrations 1142, 1143, 1144 in order.
2. Run the verification SQL in the staging Supabase SQL Editor and confirm eight `passed=true` rows.
3. With an authorized kitchen employee, test `new → preparing → ready → served` and invalid transitions.
4. Attempt insert/update/delete of served order items and verify rejection; check table/motel order screens and financial records.
5. Test concurrent serve-versus-item-edit sessions; confirm no inconsistent completion or deadlocks.
6. Test scheduled meals, motel food requests, sign-out/account switching, and iPhone/Windows UI.

## Section 05 measured status
- Source components identified: 4/4.
- Major live acceptance areas passed: 0/5 (no live database/device environment tested).
- 5 acceptance areas still require live verification; exact number of future coding steps is unknown.
- Flutter compile, live Supabase, and device tests: not run.
