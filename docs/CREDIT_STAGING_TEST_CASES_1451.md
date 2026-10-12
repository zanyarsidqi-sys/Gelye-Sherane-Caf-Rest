# Credit source validation scenarios — Upgrade 1451

These are **unexecuted staging test specifications**. Use a disposable staging database with real migrations and controlled authenticated test identities.

1. Reject cancelled credit request before any posting.
2. Reject missing invoice with P0002.
3. Reject inactive barcode registry.
4. Reject suspended barcode registry.
5. Reject mismatched registry/account reference.
6. Reject link without verified_at.
7. Reject link without verified_by.
8. Reject unverified customer.
9. Reject credit charge above total credit limit.
10. Reject conflicting latest-timestamp journal balances.
11. Reject cash-settled invoice.
12. Reject duplicate request with changed idempotency key.
13. Retry exact request/key and verify same journal id, unchanged balance.
14. Two concurrent requests against one invoice: at most one journal charge.
15. Two concurrent requests against one account: credit limit enforced.
16. Trigger rejection rolls back both account update and journal insertion.
17. Permission-denied role cannot charge.
18. Successful charge does not certify invoice paid or Dashboard IQD.
19. Existing prepaid evidence is not treated as confirmed settlement.
20. Test migration ordering, RLS, journal trigger and original 35-section navigation.
