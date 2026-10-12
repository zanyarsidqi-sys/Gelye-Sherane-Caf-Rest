# Credit source guard staging plan — upgrade 1452

Not executed in a connected database. Run on an isolated staging copy with transaction rollback and seeded representative records. Do not use production customer data.

1. Valid pending credit request, active registry, verified link/customer, source lines matching invoice: expect insert allowed only with matching already-updated bounded account.
2. Cancelled verification request: reject.
3. Wrong source amount: reject.
4. Non-credit or non-draft intent: reject.
5. Invoice status not unpaid: reject.
6. Zero invoice total: reject.
7. Source count mismatch: reject.
8. Source amount mismatch: reject.
9. Existing cash settlement: reject.
10. Second draft on invoice: reject.
11. Competing pending verification request: reject.
12. Existing charge for invoice via other request: reject.
13. Inactive barcode: reject.
14. Unverified registry link: reject.
15. Registry account reference mismatch: reject.
16. Unverified customer: reject.
17. Journal balance not matching account: reject.
18. Duplicate request charge: reject.
19. Concurrent same-request posts: exactly one charge, retry idempotent via RPC.
20. Concurrent different-request same-invoice posts: at most one charge.
21. Failure after account update before journal insert: account update rolled back.
22. Ensure no paid invoice flag, prepaid allocation or certified Dashboard IQD is produced.

Requires actual PostgreSQL staging execution; source checks cannot establish concurrency correctness.
