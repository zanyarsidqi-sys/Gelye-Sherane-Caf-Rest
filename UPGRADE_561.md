# Upgrade 561 — pricing-mode confirmation

The replacement confirmation RPC now requires the order's quoted `tourism_mode` boolean. It locks the order row, rejects a changed pricing mode, and then invokes the existing quantity- and price-confirming transaction within the same database transaction. The seven-argument RPC is revoked from client roles. Flutter passes the mode returned by the server quote and rejects malformed mode fields.

Deployment: apply migration 561 after 560. Confirm that no other clients rely on the revoked seven-argument endpoint. Test normal/tourism mode changes between quote and commit against a staging Supabase database.

Verification scope: ZIP integrity and static source assertions only; Flutter compilation and live Supabase tests not run.
