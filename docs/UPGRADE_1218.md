# Upgrade 1218 — Station notifications foundation

- Existing `gs_set_preparation_station` configures station and printer/POS target; `gs_route_confirmed_order` routes accepted orders and creates idempotent station tickets.
- Existing `gs_cafe_station_employee_assignments` supports multiple station memberships per employee.
- New SQL trigger creates one in-app notification for each active station employee on station ticket creation, with employee-scoped list and mark-seen RPCs.
- The existing ticket dispatch lease/acknowledgement and manual retry process is retained; it does NOT physically print until a trusted device worker is deployed.
- Existing correction notices have their own queue; printing them is NOT connected in this upgrade.
- Outstanding: UI for station notification inbox, trusted printer worker binding, correction print queue, printer error handling end-to-end, complete server-side station read-access audit.
- Flutter compilation, live Supabase deployment, physical printer and integration tests deferred.
