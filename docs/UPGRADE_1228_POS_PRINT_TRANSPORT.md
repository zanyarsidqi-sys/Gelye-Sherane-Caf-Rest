# Upgrade 1228 — Secure POS print dispatch transport

Added `claim_print` and `ack_print` actions to the existing station-device-auth Edge Function, which hashes the device session token and calls the service-role-only, station-scoped PostgreSQL functions added in Upgrade 1227. Added Flutter service methods to claim tickets and acknowledge a specific attempt. Device token remains in secure storage.

Security boundaries: station membership and print authorization are enforced by the database; the service role key stays server-side. Ticket acknowledgments require a matching attempt, avoiding stale acknowledgments.

**Still not complete:** no physical printer driver, no ticket-content renderer, no continuous polling worker, no correction-specific print payload, no bill printer implementation, and no safe manual requeue for uncertain print jobs. An acknowledgment is not proof of paper printing. Do not automatically retry ambiguous outcomes.

Static ZIP checks only. Flutter compilation, live Supabase, and physical printer tests deferred.
