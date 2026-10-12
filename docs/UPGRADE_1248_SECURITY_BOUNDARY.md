# Upgrade 1248 — Station device authentication boundary

Fixed the dangerous `current_user <> 'service_role'` guard in six named station-device RPC families: inside `SECURITY DEFINER`, `current_user` is the function owner, not the invoker. The migration replaces that guard with `auth.role() IS DISTINCT FROM 'service_role'`, and explicitly revokes public, anonymous and authenticated execution rights. Station device clients must never receive the Supabase service role key. Station management remains inside Kitchen.

## Remaining mandatory security work
- Verify `auth.role()` behavior, grants, RPC overloads and session claims in live staging Supabase; no database was contacted.
- Perform negative authorization tests for anon/authenticated users and expired/revoked station tokens.
- Add gateway-level per-IP login throttling; existing per-username SQL rate limits do not replace it.
- Review other station RPCs and Edge Function paths, including revision printing, for session binding and permissions.
- Verify edge deployment uses service credentials only on the server, HTTPS, restricted secrets and monitoring.
- Flutter compilation, physical printer tests and live Supabase tests are deferred as requested.
