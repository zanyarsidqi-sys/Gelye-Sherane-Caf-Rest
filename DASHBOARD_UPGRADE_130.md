# Dashboard Upgrade 130 — Trusted payment verification intake

Adds a **server-only** RPC for storing independently verified provider
events in the existing payment-verification inbox. It is inaccessible
to staff/client roles, checks evidence method, reference, amount,
currency and provider-event replay, and locks evidence during intake.

**Critical boundary:** This RPC does NOT verify a provider signature by
itself. It must be invoked by a private service-role backend **only after**
the backend verifies the provider's signature AND independently confirms
the successful transaction with the provider's API. Without the provider
API credentials and webhook specification, that integration is not
implemented. Never expose service-role credentials to Flutter.

No cash, customer credit balance, unified payment ledger or table checkout
is changed by this upgrade. Payment posting remains disabled until trusted
provider verification, ledger uniqueness, refunds and reconciliation are
implemented and tested. This is an intake operation, not payment settlement.

ZIP integrity checked; Supabase execution not tested.
