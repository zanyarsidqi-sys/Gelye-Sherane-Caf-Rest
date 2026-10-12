# Upgrade 1460 — credit posting reentrancy and session integrity

## Actual change
The existing verified-credit posting Flutter action now locks its in-flight state before the first awaited input dialog, preventing overlapping confirmation dialogs and duplicate in-flight calls from rapid taps. A second employee identity check immediately before the RPC prevents a changed session during confirmation from submitting a debit under a different login. The existing deterministic idempotency key, result validation and disabled-by-default staging gate remain unchanged.

## Deployment and verification
1. Run `python3 tests/test_credit_posting_reentrancy_1460.py` (source contract only).
2. Run `flutter analyze` and `flutter test` in an environment with Flutter installed.
3. In an isolated Supabase staging database, apply migrations in order and test two rapid taps, cancel/retry, employee logout/login during confirmation, two simultaneous devices, RPC timeout after commit, duplicate request, RLS-denied staff, and rollback of journal/account/invoice link triggers.
4. Do not enable GS_ENABLE_VERIFIED_CREDIT_POSTING in production before staging signoff. The credit charge does not settle an invoice, allocate prepaid funds or certify Dashboard totals.

## Preserved
All prior archive entries except the intentional Flutter file replacement are byte-for-byte unchanged. All 35 management sections, navigation, filters, footer, security rules and existing rollback materials remain present.
