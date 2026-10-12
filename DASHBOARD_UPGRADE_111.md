# Dashboard Upgrade 111 — Visible physical checkout status

The existing Flutter table-details screen now calls the Upgrade 110
`gs_visit_physical_checkout_status` RPC. Employees can see departure,
cleaning, required shisha pickup, the current physical blocker, and refresh
from the server. This connects an existing backend capability to a usable UI
instead of creating another diagnostic SQL migration.

**Financial settlement and release are still disabled.** Physical readiness
is not payment verification. No checkout/release button was introduced.

Verification: ZIP CRC, duplicate path check and static text assertions only.
Flutter compilation, Supabase deployment, and live end-to-end testing pending.
