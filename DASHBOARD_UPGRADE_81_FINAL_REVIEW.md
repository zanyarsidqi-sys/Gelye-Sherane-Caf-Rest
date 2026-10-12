# Dashboard Upgrade 81 — Final Review and Test Preparation

## Evidence-based status

This completes the **81-step planning/review milestone**, NOT the implementation or verification of a production-ready Dashboard. Existing Phase 3 ~54% is a historical estimate and cannot be updated without measured acceptance tests.

- Project ZIP entries: 379
- Dart files: 118
- SQL files: 75
- Function names defined more than once: 10. Redefinitions may be intentional; signatures and execution order must be tested.
- Archive CRC: PASS. Duplicate ZIP entry names: NONE.
- Flutter compilation: NOT RUN.
- Supabase migration deployment: NOT RUN.
- iPhone/Windows tests: NOT RUN.

## Critical acceptance blockers

1. **Transfers:** Actual table bill transfer remains disabled. Implement authoritative per-item settlement, credit, waiver and refund allocations, then atomic idempotent execution. Never enable the transfer endpoint on the strength of read-only preflight alone.
2. **Owner Guest:** AAL2 review is only an attestation, not a posted waiver. Implement owner step-up and audited ledger-backed waiver posting before showing `Owner Verified` as a financially effective state.
3. **Motel Meals:** QR lookup alone does not prove meal entitlement. Integrate reception's trusted reservation service, room identity, included quantities, prepaid balance and duplicate redemption prevention.
4. **Offline:** Notification cursor synchronization is not encrypted offline caching, financial queuing or conflict resolution. Keep payments and table state changes online-only until safe sync is implemented.
5. **Table lifecycle:** Guest movement and bill-transfer requests are not completed actions. Checkout requires visit-specific settlement and physical departure, cleaning, and shisha clearance.
6. **SQL dependencies:** Staging migration apply is necessary. Function redefinitions, table/column assumptions, RLS, security-definer boundaries and grants need review.
7. **Device QA:** Real Flutter compile, iPhone and Windows layouts, login/MFA, permission revocation, and navigation tests remain.

## Staging acceptance checklist

- [ ] Apply every migration in a disposable Supabase project from clean state.
- [ ] Compare RPC signatures against Dart calls; resolve SQL errors in order.
- [ ] Verify role- and AAL2-based access using real authenticated sessions (not SQL Editor postgres role).
- [ ] Simulate concurrent payments and duplicate transaction keys; never double count.
- [ ] Confirm transfer of partial unpaid item keeps original price and never moves settled value.
- [ ] Confirm table movement respects capacity, reservation holds and occupancy.
- [ ] Confirm complimentary approval cannot bypass financial posting or impersonate the owner.
- [ ] Confirm motel QR expires, revokes and cannot be redeemed twice.
- [ ] Confirm offline login/logout and role revocation isolate employee data.
- [ ] Run `flutter analyze`, Flutter widget tests and iOS/Windows/web builds.
- [ ] Capture actual screenshots and compare with proposed iPhone and Windows designs.

## Recommended next action

Remain on Section 01 — Dashboard. Continue with actual blocking implementation and staging tests (new stages if necessary), rather than treating 81/81 as completion or moving automatically to Section 02.
