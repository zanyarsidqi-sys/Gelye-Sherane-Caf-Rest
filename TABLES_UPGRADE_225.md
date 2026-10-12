# Upgrade 225 — POS device registration UI and enabled controls

- Tables > POS Devices & Print Routing now has **Register POS device** with name, model, department and unique device identifier. Registration uses the manager-checked `gs_register_cafe_pos_device` RPC from migration 224.
- Registered devices show an enabled toggle. New manager-only RPC `gs_set_cafe_pos_device_enabled` controls eligibility; no device is physically contacted.
- Device registry and routing policy can be refreshed. Device connectivity is only last-reported heartbeat, not a verified live connection.
- Existing migration history and 35-section source remain intact.
- **Not implemented:** SUNMI SDK, direct or automatic printing, actual offline storage/synchronization, gateway, physical print status.
- Tables 94% estimated; Customers paused 45%. No Flutter compile or live Supabase testing.
