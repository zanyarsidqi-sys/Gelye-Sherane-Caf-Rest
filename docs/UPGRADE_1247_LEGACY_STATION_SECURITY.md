# Upgrade 1247 — Legacy station administration hardening

## Source audit findings
- Legacy `gs_1217_save_station` could modify any station with broad supervisor permission.
- Legacy `gs_assign_station_employee` could assign employees to any enabled station.
- Legacy assignment and device-user directories exposed assignments for all stations to any supervisor.
- Legacy `gs_1223_revoke_station_sessions` could revoke another station's POS sessions.

## Changes
- Replaced these five RPC bodies with per-station checks using `gs_1246_can_manage_station`, which requires MFA, Kitchen edit, active supervisor and explicit station scope.
- Revoking employee assignment also deactivates device-user assignments at that station; device/session revocation may require additional operational policy review.
- Reaffirmed service-only station login/heartbeat/logout grants.
- Kept Kitchen's existing station-management UI; no Workplace dependency added.

## Limitations / deployment checks
- **Not tested against live Supabase.** Validate function signatures, role ownership, and migration ordering on a disposable staging clone.
- Existing service-role-only functions check `current_user` inside SECURITY DEFINER; PostgreSQL SECURITY DEFINER changes `current_user` to the function owner. This is a potential authentication boundary flaw; the Edge Function and RPC grants require dedicated review before deployment. Do not treat the service-role check alone as a secure guarantee.
- All other older station RPCs and station device login/session token handling require end-to-end authorization tests.
- Flutter compilation, live Supabase and physical printer tests deferred by request.
