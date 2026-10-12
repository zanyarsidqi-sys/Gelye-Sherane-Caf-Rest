# Credit withdrawal state contract (Phase 3)

Added `lib/shared/credit_request_state.dart` and tests in `test/credit_request_state_test.dart`.

Draft -> Pending approval -> Approved -> Posted. Pending may be rejected/cancelled; approved may be cancelled before posting. Posted may be reversed only via an auditable compensating transaction. A posted record must never be deleted or edited to undo payment.

**Safety boundary:** The Dart state helper is not an authorization mechanism. Server-side Supabase RPCs must validate authenticated role, barcode-to-account mapping, order ownership, amount calculated from order items, available credit, idempotency key and atomic ledger posting. No withdrawal is active in this build.

Manager approval is the conservative default until the business policy is confirmed. The state helper does not implement the actual approval or debit.

Tomorrow run: `flutter pub get && flutter analyze && flutter test test/credit_request_state_test.dart`.
