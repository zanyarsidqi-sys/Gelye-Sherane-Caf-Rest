# Current checkpoint: Upgrade 1492 (12 October 2026)

Build repairs and shared session protection are implemented. 68 Flutter tests and 5 existing Python source checks passed; JavaScript web release builds passed. Live Supabase and native-device verification remain outstanding. Read UPGRADE_1492.md for the actual scope and limitations.

---

## Historical checkpoint (retained)

# Gelye Sherane Cafe — coding-only checkpoint (2026-10-10)

## Updated
- lib/services/employee_permission_service.dart: redact user ID in debug output; fail closed on duplicate normalized permission keys.
- lib/services/tourism_pricing_service.dart: deterministic normal/tourism pricing modes, motel tourism enforcement helper, integer IQD line totals.
- test/tourism_pricing_service_test.dart: three tests for table defaults, motel pricing, and line total validation.

## Important limitations
- Tourism pricing helper is not yet connected to UI/order submission or Supabase RPC. Backend price enforcement is still required.
- No Flutter SDK available in the current environment; tests, analysis, build, runtime, and RLS behavior remain unverified.
- Previous Phase 3 ~54% was an estimate, not a verified measure. Do not increase overall completion based on these isolated edits.
- Existing Dashboard access-denied issue remains unresolved pending authenticated testing and database policy review.

## Next coding passes
- Integrate tourism pricing into table/motel order forms and immutable charged-price snapshots.
- Review and harden credit payment flow and server authorization.
- Continue each of 35 sections; postpone device and Supabase live verification.
