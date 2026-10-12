# Credit charge staging test plan (not executed)

1. Deploy all earlier migrations in order in a disposable staging database.
2. Run predeployment crosswalk and credit-journal diagnostics; resolve conflicts without deleting accounting evidence.
3. Verify denied access for anonymous, staff lacking motel view, finance edit, or credit edit.
4. With authorized MFA staff and an eligible source, post a charge; verify exactly one journal row and one matching account increment.
5. Retry same request/key; expect `already_posted=true` and no second increment.
6. Retry same request with different key; expect rejection and no mutation.
7. Reuse same key for another request; expect rejection.
8. Run simultaneous identical requests; expect exactly one charge.
9. Run simultaneous different requests against same credit limit; ensure account never exceeds limit.
10. Revoke registry link while posting; verify row locking prevents a stale verified link.
11. Test mismatched draft, invoice, account, suspended customer, and over-limit requests; ensure rollback.
12. Verify existing credit journal triggers accept successful posting; any trigger failure rolls back account update.
13. Verify motel invoice is NOT marked paid and no prepaid allocation or unified ledger entry is fabricated.
14. Confirm both Dashboard cards still show `Amount unavailable` until exhaustive reconciliation is certified.

This checklist is not evidence of executed tests.
