# Upgrade 569 — Cross-device request-ID recovery

Adds a read-only request-ID lookup to the Table Orders board. Employees can check an original UUID from another device using the existing actor-scoped `gs_table_replacement_request_status` RPC. Validates UUID format and response shape, shows committed receipt details, and explicitly warns that an absent receipt does not authorize a retry. Does not execute replacement mutations or change database privileges.

Verification: static regression assertions only; Flutter compilation and live Supabase integration not performed.
