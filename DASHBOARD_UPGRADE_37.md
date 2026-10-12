# Dashboard Upgrade 37 - Table Service Integration

- Added table-specific entry from Live Table Map detail into the read-only Table Service Requests queue.
- Passes actual backend-provided table identifier; does not fabricate one.
- Expanded cleaning-needed map status and icon support.
- Retains permissions and unavailable backend behavior; no unsafe client-side task mutations.
- Pending: server task RPC, cashier assignments, employee notifications, QR intake, release guards, and end-to-end verification.
- No Flutter compilation or Supabase migration was executed.
