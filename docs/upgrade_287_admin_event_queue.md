# Upgrade 287 — Admin event queue
- Added permission-gated Supabase queue RPC including requested catering quantities.
- Added responsive Flutter admin event review screen and Tables section navigation.
- Admin can review guest count, dates, rental model, service requests and preparation quantities, and approve/reject with notes.
- Review RPC from Upgrade 285 retains audit records; this upgrade does not create kitchen tickets or charges.
## Not yet verified
- Flutter compile and live Supabase migrations/RPC tests are not available in this runtime.
- UI uses device local time; explicit Asia/Baghdad display still required.
- Venue-wide capacity and other legacy reservation write paths need further conflict auditing.
- 5 percentage points of completion cannot be substantiated without integrated tests.
