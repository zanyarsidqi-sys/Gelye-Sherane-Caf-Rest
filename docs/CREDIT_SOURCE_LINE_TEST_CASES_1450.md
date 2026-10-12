# Credit posting staging test cases (not executed)
1. Valid single-line invoice with exact amount and one draft: post succeeds once.
2. Same request and idempotency key: returns already_posted, no second debit.
3. Same request with changed key: reject.
4. Invoice with missing line: reject without balance or journal change.
5. Invoice with extra line: reject without balance or journal change.
6. Invoice with incorrect source amount: reject without balance or journal change.
7. Invoice with zero total: reject.
8. Conflicting second payment draft: reject.
9. Existing cash settlement: reject.
10. Concurrent identical request transactions: exactly one journal charge.
11. Concurrent distinct requests same invoice: at most one charge.
12. Insufficient account credit: reject with no changes.
13. Trigger rejection during insert: account balance rolls back.
14. No finance permission or no authenticated user: reject.
15. Existing credit account/journal discrepancy: reject.
16. Prepaid/credit double allocation: not implemented; must remain blocked.
These are test specifications, not test results. Use a dedicated seeded staging DB and
rollback each case. Never run payment tests on production data.
