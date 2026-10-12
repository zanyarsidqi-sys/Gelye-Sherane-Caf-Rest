# Dashboard Upgrade 73 — Static Review & Test Readiness

## Scope and evidence
- Source: Upgrade 72 archive; 365 ZIP entries, 118 Dart files, 70 SQL migration files.
- Archive was readable and passed ZIP CRC validation. This is **not** proof that SQL applies or Dart compiles.
- No Flutter SDK, connected Supabase instance, payment-provider sandbox, or device test was used.
- The original 73-stage coding roadmap reaches its review milestone here; Dashboard is **not production complete**.

## Critical blockers (must fix before any production migration)
1. **Actual Join Tables / Transfer Bill is disabled.** Upgrade 68 intentionally raises an exception and cannot move unpaid items. Build authoritative item-level settlement allocations and one atomic idempotent execution transaction, including refunds, credit, online, and card.
2. **Owner Guest approval is not financial approval.** Upgrade 70 stores MFA-backed owner review only; it never posts a verified waiver or changes the bill. Require fresh owner authentication and signed, audited waiver posting.
3. **Motel Meal Offers are not reservation-authorized.** Reservation IDs and verification timestamps are draft fields; reception QR/barcode scanning must resolve against trusted motel reservations and prepaid entitlements.
4. **Payment migration incomplete.** `gs_cash_payments` and `gs_unified_payment_ledger` coexist. Upgrade 67 deliberately does not certify settlement. Do not sum both ledgers or release tables based on either alone.
5. **Table checkout/cleaning needs visit-specific settlement.** Earlier checkout functions compare destination table numbers across historical orders. Replace only after all order-creation paths consistently link visit IDs.
6. **Guest movement requests do not actually move guests.** Must lock source/destination tables, update guest counts, preserve active visits, and coordinate with bill-transfer state.
7. **Offline Mode is not offline transaction support.** Upgrade 72 has an online status screen. No encrypted per-employee cache, reliable sync queue, conflict handling, or offline-to-online permission recheck has been proven.
8. **Database compatibility and access policies unverified.** Validate every migration against a clean Supabase staging database; review all SECURITY DEFINER grants, roles, audit tables and RLS.
9. **Flutter compile and runtime verification outstanding.** Build iPhone, Windows, and web; test real screens, navigation, authorization, and responsive layouts.

## Concrete static findings
- SQL migrations may redefine existing RPC names: 10 distinct function names appear in multiple migration files (this can be intentional, but needs signature/order review).
- The transfer execution gate in migration 068 is intentionally fail-closed.
- The owner MFA review in migration 070 does not make an offer 'Owner Verified'.
- The unified ledger diagnostic in migration 067 always reports settlement_confirmed=false.

## Recommended next stages (new scope; estimate only)
74. SQL migration dependency and signature compatibility audit + fixes.
75. Server-authoritative payment posting and idempotent reconciliation.
76. Item-level allocation and atomic transfer execution.
77. Guest movement, capacity and table visit lifecycle.
78. Owner approval, fresh MFA and ledger-backed complimentary waivers.
79. Motel QR verification, meal entitlements, delivery and payments.
80. Offline cache, notification refresh and reconnect safety.
81. Flutter compile fixes, Supabase staging tests and device QA.
Additional stages may be needed after actual test results.

## Test cases to run
- Two cashiers submit simultaneous payments; no overpayment or double posting.
- Retry same transaction key; exactly one ledger posting.
- Move partial unpaid item to occupied table; original charged price persists.
- Reject move for paid/partially paid/waived orders without explicit allocation.
- Guest count over capacity; move rejected with no partial state change.
- Owner request cannot waive revenue without genuinely authenticated owner and ledger posting.
- Motel QR cannot be forged or reused to claim duplicate meals.
- Table cannot be available until correct visit settled, guests departed, cleaning and shisha complete.
- Employee role revoked during offline period; queued privileged actions fail on reconnect.
- Sign out on shared iPhone; previous employee's cached financial data is inaccessible.

**Conclusion:** The coding roadmap review is complete; production readiness is not verified. Remain on Section 01 until the above blockers are resolved and tested.
