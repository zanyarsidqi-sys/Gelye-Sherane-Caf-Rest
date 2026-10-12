# Upgrade 227 — Opt-in foreground Android POS heartbeats

- Adds `PosHeartbeatService` using authenticated Supabase RPC from upgrade 226.
- A manager/employee must opt in on each Android installation from POS Devices. No automatic enrollment.
- Heartbeat runs on management dashboard authorization and once per minute while foregrounded, and stops when backgrounded, logged out or disposed.
- In-flight requests are deduplicated; network errors do not interrupt ordering.
- Does not claim background service, hardware printer status, actual device identity attestation, offline synchronization, or actual printing.
- **Security limitation:** upgrade 226's heartbeat RPC updates all enabled POS devices bound to the employee, not a particular physical terminal. Implement device-scoped authentication before treating a status as hardware proof.
- Flutter compilation and Supabase live verification not performed.
