# Upgrade 234 — Station ticket content payload

- Added a database-side product-name snapshot on new station-ticket lines, and backfilled existing lines.
- Added permission-protected `gs_get_station_ticket_content(p_ticket_id)` returning only the selected ticket's product names, quantities, order destination (table/motel text), order time and status.
- `special_instructions` is explicitly NULL: the verified foundation order-item schema has no notes field. Notes capture and immutable snapshot are a future upgrade.
- Ticket contents are not yet rendered or physically printed. Worker delivery, Android SUNMI SDK, offline spool, and live testing are pending.
- Apply migration 234 after migration 233.
