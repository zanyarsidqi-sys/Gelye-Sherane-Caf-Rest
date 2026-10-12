# Upgrade 1238 — Supervisor print review interface

- Adds a Print Review tab to the employee-authenticated Kitchen section (11 tabs).
- Loads uncertain original and revision tickets from the existing station-scoped RPC.
- Displays station, queue kind, ticket number, attempt and active-lease status.
- Requires physical verification and a 10+ character explanation for either decision.
- Submits a UUIDv4 idempotency key and refreshes after submission.
- Does NOT enable a reprint action, change invoices, or expose device tokens.
- Adds an immutable trigger for the review audit table.

Security model: UI is convenience only. Existing RPC in migration 1237 enforces employee authentication, kitchen edit permission, station supervisor assignment, lease expiry, and idempotency. No station-device-only user can open this employee section by design.

Outstanding: server-side schema and RPC behavior are unverified against live Supabase. The audit table requires admin recovery policy. Printer driver and A4 PDF renderer are still outstanding. Build, live database and physical printer tests deferred. The 97% figure is an unverified source-planning estimate.
