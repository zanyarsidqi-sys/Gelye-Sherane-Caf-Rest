# Upgrade 1462 — Atomic credit invoice-link consistency

## Independent functional improvements
1. On idempotent retry, refuse to report an existing credit debit as successful if the durable invoice link is missing or inconsistent.
2. On a new charge, require the invoice link created by the existing journal trigger to exist before the RPC can commit. Any exception rolls back the charge and account update.
3. Return the source invoice UUID for independent caller-side correlation, without marking it settled.

## Deployment and live staging test (NOT executed)
Apply all earlier migrations before this one. Use a staging database with verified source fixtures. Verify: initial posting creates one journal, one matching invoice link and one account update; same-key retry returns already_posted without another debit; mismatched key fails; concurrent requests for same invoice yield at most one charge; deliberate trigger disablement in an isolated rolled-back staging transaction makes posting fail without account changes; orphaned historical link causes retry to fail; verify unauthorized staff cannot execute. Roll back staging fixture transactions and check ledger balances.

## Release gate
Flutter and PostgreSQL live tests were not available during this build. No verified prepaid source, authoritative cafe-order crosswalk, paid-invoice update or certified dashboard IQD totals are claimed.
