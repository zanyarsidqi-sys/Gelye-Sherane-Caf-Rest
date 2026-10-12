# Upgrade 224 — POS device registry and dual-mode print routing

- New migration `20261010_224_pos_devices_routing_policy.sql` with manager-only POS device registration RPC, authenticated read-only registry, and manager-controlled per-department online route (`pos`, `printer`, `both`). Offline route is fixed to `local_printer`.
- New Tables toolbar action for POS device list and department routing preferences. Uses permission-checked Supabase RPCs.
- Existing printer registry, queued print jobs, and all earlier migrations remain included.
- **Not implemented:** SUNMI SDK integration, automatic printing, gateway heartbeat, local offline order storage/sync, actual printer output, physical print confirmations. Offline mode is a saved *policy*, not a functioning offline engine. POS device registration is backend-only (no registration form yet).
- Section 02 estimated 94%; Customers paused 45%. No live Flutter or Supabase test.
