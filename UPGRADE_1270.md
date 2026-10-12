# Dashboard Upgrade 1270

Added an accessible local-time indicator above authorized Dashboard metric cards. The indicator appears only after a non-empty overview snapshot is available and labels the time as the last load on this device (not server transaction time). No new permissions, endpoints, or database changes.

Verification: ZIP CRC and source assertions. Flutter runtime and Supabase integration not tested.
