# Upgrade 427 — Employee Authorization Expiry Visibility

Employee authorization history now uses the v3 backend status RPC from Upgrade 426. It shows effective status (`expired`, `cancelled`, `awaiting_customer_consent`) and the expiration timestamp. The Cancel button is offered only while a request remains within its valid window. Existing invoice/expiry diagnostics remain available.

**Safety:** A nonexpired request is not consent. The backend still requires staff authorization for cancellation and does not authorize debit or settlement. Customer-facing authenticated consent remains unimplemented.

Requires applying Upgrade 426 migration first. Flutter compilation and live Supabase migration not tested.
