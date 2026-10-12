# Dashboard Upgrade 58 — Section 01 integration review

**Status: ROADMAP CHECKPOINT ONLY — NOT PRODUCTION READY.**

The 58 planned Dashboard coding/review stages are now accounted for, but this is **not** a claim that the Dashboard is functionally complete. Prior migrations are drafts and require SQL deployment and runtime verification. Overall Phase 3 remains **~54% historical estimate**, not a measured test result.

## Package inspection
- Full project ZIP preserved; contains the Flutter source and SQL migrations.
- Static ZIP integrity, duplicate-path check, migration inventory and key Dart-file presence checked.
- Flutter build, analyzer, automated widget tests, Supabase migration execution, live authentication/RLS checks and end-to-end tests **not performed**.

## Critical integration blockers
1. **Order creation**: Migration 052 requires an active table visit for cart orders. Audit and migrate every legacy order creation path before enabling it. Confirm migration 053 visit-opening RPC and its permissions/occupancy semantics.
2. **Cash-only reconciliation**: Migration 054 cannot prove full settlement where card, online, credit or complimentary payments exist. Build a unified idempotent payment ledger and reconcile across all tender types.
3. **Cleaning and release**: Historical order lookups and older table-release functions must be replaced with visit-specific, ledger-backed checks. Shisha pickup and cleaning completion must be verified before releasing.
4. **Owner Guest**: Migration 056 accepts staff *requests only*. There is no owner-authenticated AAL2 approval or safe complimentary ledger posting. Never mark Owner Verified from staff action.
5. **Motel meals**: Barcode/QR reservation authentication, exact item scheduling, included/prepaid/pay-on-delivery verification and double-charge protection need transaction-safe implementation.
6. **Join tables / transfer bill**: Existing draft is not an actual transfer; implement atomic item splitting, payment attribution, destination capacity, price snapshots, idempotency, reversals and audit.
7. **Offline and notifications**: Migration 058 supports read-only notification cursors, not offline payment/approval actions or push delivery. Read-state updates require separate refresh.
8. **Security**: Verify RLS, function privileges, MFA, employee roles, owner identity, audit event writes, and that restrictive AAL2 policies do not silently deny legitimate dashboard access.
9. **App integration**: Confirm the Dashboard UI actually calls the new RPCs and handles errors, loading, reconnects and permissions. The new draft foundations are not all wired to interactive UI.
10. **Migration consistency**: Test all SQL migrations in a fresh and upgrade database; function/table signatures, constraints and privileges can diverge. Resolve any failing migration before rollout.

## Required release gates
- Fresh-database and upgrade-database migration tests pass.
- `flutter analyze`, widget tests and iPhone/Windows build checks pass.
- Authenticated permissions/MFA/RLS and unauthorized-access tests pass.
- Concurrent checkout, partial payment, owner approval, visit transfer and double-charge tests pass.
- Table turnover tests: guest departure, shisha pickup, cleaning, safe release and reopening.
- Motel reservation scanning, scheduling, kitchen dispatch and delivery/payment verification tested.
- Reconnect/offline data isolation, notification sync and audit logs tested.

## UI previews
The bundled `DASHBOARD_UPGRADE_58_DESIGN_PREVIEW.png` is an **illustrative design concept**. It is not a screenshot from a running Flutter app and its example data/status labels are fictional. The graphic's “Upgrade 58 Complete” label means the **planned review milestone**, not implementation/test completion.

## Next recommendation
**Keep Section 01 in integration/testing until blockers are closed.** Do not advance to Section 02 — Tables as a completed Dashboard handoff without explicit user approval.
