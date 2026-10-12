# Upgrade 1246 — Station-scoped administration (source only)

## Actual changes
- Explicit per-station admin grants, requiring authenticated AAL2, Kitchen edit and active supervisor status.
- Harden device registration/update, device-user authorization, product routing and station account provisioning against cross-station writes.
- Prevent silent reassignment of registered device to another station; block disabling device with active user assignments.
- Station account setup and device directory only list granted stations.
- Remove authenticated access to legacy Tables station configuration RPC which bypassed Kitchen scopes.
- Station creation requires a separate explicit creation-admin grant.

## Bootstrap (trusted DBA only)
```sql
insert into public.gs_cafe_station_creation_admins(employee_id) values ('<supervisor-auth-uuid>');
insert into public.gs_cafe_station_scope_admins(employee_id,station_key) values ('<supervisor-auth-uuid>','<existing-station-key>');
```
Do not paste placeholders as actual SQL. Grant new station scopes after creation.

## Remaining security work
Other historical station-management RPCs may still use global supervisor checks and must be audited/restricted before production. In particular gs_1217_save_station, gs_assign_station_employee and station POS session APIs need full cross-station assessment. The existing station scope grant table is DBA-managed, not self-service. No client compile, migration application, live RLS, hardware or printer tests were performed.
