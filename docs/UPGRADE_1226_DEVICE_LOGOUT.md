# Upgrade 1226 - Station device server logout

Added service-role-only token-hash revocation RPC, logout Edge Function action, secure-storage logout flow, and UI retry error. Expired/revoked heartbeat sessions clear locally; transient network errors retain tokens for retry. Existing 30-second heartbeat and reconnect action preserved. Physical printer state is not inferred from heartbeat.

Limitations: No offline server revocation guarantee; if the network is down, administrator must revoke station sessions server-side. Login edge rate limiting, device-bound tokens, automatic printing, and integration testing remain pending. Flutter compilation, Supabase live tests and physical printer tests intentionally deferred.
