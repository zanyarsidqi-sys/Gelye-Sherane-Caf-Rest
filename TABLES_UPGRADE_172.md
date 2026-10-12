# Tables Upgrade 172 — Revocable unique table QR identity

Implemented per-table unique random QR token storage and Supabase RPCs:
- `gs_get_table_qr(table_number)` creates once or retrieves token for authorized table managers.
- `gs_rotate_table_qr(table_number)` revokes the old token and generates a replacement.
- `gs_resolve_table_qr(token)` allows public phone-camera website flows to
  resolve only the table number; it reveals no guest or payment information.

**Not implemented yet:** actual QR image generation, printable PDF/stickers,
website URL/router, public mobile ordering, customer authorization, reservation
flow, or payment processing. Token lookup does not authorize placing orders;
the server must independently validate the active table visit, prices and order.

Normal/tourism mode, future reservations, reservation notifications, shisha
flavor and scheduled tea pre-orders, individual/full/partial payment with
stay/checkout are outstanding required Tables features.

**Tables estimate: 51%**, with expanded requirements still outstanding.
No Flutter build or live Supabase migration testing performed.
