# Upgrade 1224 — Station device login hardening (source-only)

- Fixes critical failed-login rate-limit rollback: the prior SQL raised an exception after INSERT, undoing the failed-attempt record. The replacement function returns zero rows instead and keeps the attempt committed. Per-username lockout: five failures within 15 minutes, with serialized attempts.
- Adds a Flutter station POS login screen with username/password, concealed password, safe error handling, and no password persistence. The screen is a standalone component and has **not yet been wired into app routing**.
- Tightens Edge Function request-body byte-size checking and error responses. The token is returned to the caller but intentionally not persisted; it must be handled by a secure device session service before enabling printing.

**Not complete:** public-edge IP-based rate limiting/WAF, persistent secure token storage, authenticated printer job fetching, device heartbeat scheduling, Add Station wizard, physical printing, and live security testing. Do not deploy as a production POS login yet. SQL migration must be applied after 1223. Flutter compilation and live Supabase/device testing deferred.
