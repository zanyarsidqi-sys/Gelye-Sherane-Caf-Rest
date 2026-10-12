# Upgrade 226 — POS device heartbeat status

- Manager can bind each POS device to an authenticated employee account (UUID).
- Bound employee can send a **manual** heartbeat using the Tables POS Devices dialog.
- Last heartbeat determines Online (within 2 minutes), Offline/stale, Never connected, or Disabled.
- The heartbeat is a signed-in account signal, not proof of SUNMI printer connectivity.
- Device polling/periodic heartbeat agent, physical printing, local offline storage and synchronization remain unimplemented.
- Migration 226 must be applied after 224 and 225.
- No live Supabase/Flutter compilation tests were performed.
