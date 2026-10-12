# Upgrade 1222 — Station account provisioning (source-only)

Adds manager-controlled username/password accounts for existing configured preparation stations, printing capability flags, hashed credentials, session-revocation data and online heartbeat read model. A password reset revokes prior sessions. One account per station can be used by several separately registered devices; do not share employee credentials.

IMPORTANT: Device login, token issuance, token validation, heartbeat ingestion and physical printing are NOT implemented by this migration. A trusted, rate-limited Supabase Edge Function with device-bound sessions is required before these accounts can authenticate POS devices. Do not expose a public password-check SQL RPC or grant direct table access. A 'false' online flag means no verified recent heartbeat, not necessarily a broken printer.

The station itself must already exist with a valid POS/printer target. This upgrade does not implement the Add Station wizard or the pending 1222 service request UI work.

Verification: ZIP integrity and static SQL contract checks only; Flutter, Supabase migrations and printer devices untested.
