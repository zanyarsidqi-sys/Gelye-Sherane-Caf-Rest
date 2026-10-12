# Upgrade 1253 — station-scoped customer-name projection

## Concrete finding
The legacy `gs_kitchen_station_ticket_details` RPC checked general Kitchen view permission but did not require assignment to the ticket's station. An authenticated Kitchen viewer could request another station's ticket ID and receive customer labels and preparation notes.

## Source fix
The replacement RPC now requires AAL2, Kitchen view permission, and either active assignment to the ticket station or explicit station-management scope. It retains the original return columns and returns null for blank customer labels. No billing or printing state is modified.

## Outstanding review
Other Kitchen order-list RPCs and revision ticket details may have different authorization paths and must be audited separately. Employee-device assignment and station POS session functions require staging role tests, including revoked assignments and expired sessions. Product routing and POS printing are not claimed verified.

## Deferred
Flutter compilation, live Supabase migration/role tests, physical printers. Run migration in staging first; test an assigned employee, a different-station employee, an authorized supervisor, missing MFA, and a revoked assignment.
