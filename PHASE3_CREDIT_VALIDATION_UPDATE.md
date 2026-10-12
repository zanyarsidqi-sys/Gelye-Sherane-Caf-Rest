# Phase 3 — Credit draft validation

- Reusable pure-Dart validation for positive whole-IQD amounts, required values, effective pricing mode and masked barcode review.
- Motel Orders always resolve to Tourism mode in the local draft preview.
- Customer barcode is masked in the review card; it remains in the input field until cleared.
- Added `test/credit_draft_validation_test.dart`.
- NO credit withdrawal request is sent, NO account is verified, NO funds are deducted, and NO schema changes were applied.

## Security blockers before enabling credit payments
1. Inspect real Supabase account/ledger/order schema and RLS policies.
2. Confirm whether manager approval is mandatory or conditional.
3. Backend must calculate authoritative order amount, verify barcode/account and available balance, use an idempotency key, and perform atomic posting with audit logs.
4. Never accept a client-supplied balance or client-supplied order total as authoritative.

## Tomorrow
Run `flutter pub get`, `flutter analyze`, and `flutter test` on Windows. Inspect the read-only SQL under `supabase/verification/` before deciding on migrations.
