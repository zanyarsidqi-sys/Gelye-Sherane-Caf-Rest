# Upgrade 1232 — Secure station revision event creation

Added authorized RPC `gs_1232_submit_station_revision`, accepting an original ticket,
revision type (CORRECTION, REPLACEMENT, CANCELLATION), reason, item IDs/quantities,
and UUID idempotency key. It verifies order item membership in the original station
ticket, snapshots product and customer data from the original immutable payload,
records who requested the revision, and creates a separate station-specific queue row.
It does not change customer billing or financial records. A wrong-item refund or
replacement charge must be performed in the existing authorized billing workflow.

**Not yet complete:** dedicated revision device claim/resolve/ack, POS worker handling,
printer hardware integration, confirmed payment adjustment, and all-screen company
footer integration. The revision queue must not be represented as physically printed.

Corrected a literal backslash-n syntax error in the previous (untested) 1231 SQL
migration. This package is source-only and assumes no prior migrations were applied.

A4 official invoice remains a separate requested feature in the Invoices & Payments
section; no official compliance is asserted. Flutter build, live Supabase and physical
printer tests were not performed.
