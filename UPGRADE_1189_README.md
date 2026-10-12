# Upgrade 1189: Station employee assignments

Adds explicit station assignments and supervisor records. Staff need both existing Kitchen permissions and active assignment to accept, finish, pick up or deliver tickets. The station preparation queue filters to assigned stations.

Rollout: no staff are assigned automatically. A trusted database administrator must insert the first supervisor's existing auth.users UUID into gs_cafe_station_supervisors. That supervisor can use gs_assign_station_employee(station_key,employee_id,active).

Not yet complete: device registration, supervisor assignment UI, comprehensive station-scoped permissions on all older read RPCs, Flutter compilation and live Supabase verification. Do not deploy to production until legacy read RPC permissions are audited.
