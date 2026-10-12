# Upgrade 1255 — Station device session and ticket access review

## Concrete source changes
- Revision print claim, resolve and acknowledge RPCs now require `auth.role() = service_role`, in addition to the existing station-bound session token verification. The helper also returns no station for other roles.
- Original print acknowledgement now rejects an expired/null lease and requires a recent device heartbeat. This prevents a late device result from bypassing the supervisor review path.
- Review request idempotency now checks current station authority before returning the prior audit identifier. AAL2 MFA is explicit.
- Reapply least-privilege EXECUTE grants on affected device RPCs.

## Deferred / deployment blockers
- Apply and test migrations in order on staging; verify Supabase JWT role context inside SECURITY DEFINER functions.
- Test two stations, revoked sessions, expired leases, concurrency, cross-station access and repeat requests.
- Review remaining station RPCs and the Edge Function gateway rate limits; no claim of exhaustive security audit.
- Flutter compilation, live Supabase and physical printer tests are deferred by request.
- No physical printer integration or A4 PDF generation is implied by this upgrade.
