# Upgrade 138 — Flutter mixed-payment checkout readiness

Adds a live, read-only mixed-payment checkout preflight card to the
Dashboard table details, using the server-issued active visit ID and
`gs_mixed_visit_checkout_preflight` RPC from Upgrade 136.

Displays order counts by finance attestation type, missing approvals,
cancelled-order financial conflicts, physical checkout readiness and
server-provided blocking reasons. Refreshes on demand and fails closed
if RPC permissions/migrations are missing.

There is deliberately **no mixed-payment release button**: Upgrade 137
keeps actual release disabled until provider verification integration
and staging tests pass. Cash-only release remains unchanged.

ZIP integrity verified. Flutter compilation and live Supabase testing
were not possible in this environment.
