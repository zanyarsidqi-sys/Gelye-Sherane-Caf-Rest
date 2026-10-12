# Tables Upgrade 232 — Station Dispatch Queue Protocol

Added migration `20261010_232_station_ticket_dispatch.sql`.

- Claim exactly one queued ticket with row lock and 90-second lease; mark it **unknown** immediately to avoid accidental duplicate printing after uncertain delivery.
- POS claims require device assignment to the authenticated employee; printer claims require Tables edit permission.
- Worker acknowledges `received`, `printed`, or `failed` with an audit event. `received` does **not** mean printed.
- Managers can explicitly requeue failed/unknown tickets with a reason. No automatic retry after an uncertain send.
- Alert RPC shows failed and expired-lease unknown tickets.

**Not yet implemented:** physical SUNMI/ESC-POS device transport, print payload formatting, local/offline gateway, live printer acknowledgements, Flutter dispatcher UI, automated dispatch process, live Supabase or Flutter tests. Do not treat SQL ticket creation as physical printing.
