# Upgrade 1237 — Persistent uncertain-print manual review

Adds station-scoped, supervisor-only listing and resolution of UNKNOWN print attempts for original and revision tickets. The review records are durable, append-only through denied table grants, and carry actor, timestamp, station, attempt, explanation and unique request key.

A reviewer must physically verify whether the ticket printed, and must wait until the print lease expires. Confirmed printed becomes `printed`; confirmed not printed becomes `failed`. **Neither outcome automatically requeues or reprints**. Any reprint must use a separately authorized future workflow. Duplicate review requests are idempotent only if all fields and the reviewer match.

Known constraints: the `gs_cafe_station_supervisors.station_key` field must exist as expected in the live schema; verify before migration. Existing 1227 acknowledgment lease rules, role privileges, and schema consistency require deployment tests. No UI wired to this service yet. Flutter, live Supabase and physical printer testing intentionally deferred. No guarantee of printer hardware success.
