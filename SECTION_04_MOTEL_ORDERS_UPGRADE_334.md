# Upgrade 334 — Unique permanent room QR identity foundation

Each room/villa/chalet can have a distinct persistent opaque UUID QR token. Staff with motel_orders can_edit can provision or rotate a token using gs_staff_provision_motel_room_qr(room_label, rotate). QR scan clients can resolve it via gs_public_identify_motel_room_qr(token) and receive the room label only.

**Security:** Physical room QR identifies a location, not a guest or valid stay. Before placing or charging a room order, backend must verify an active stay and guest authorization; do not trust room_label from the client. Existing staff confirmation remains required. Rotating a token invalidates the old printed QR.

**Remaining:** Build print/display QR interface, wire customer scanner and occupancy-backed ordering to this RPC, verify against actual motel reservation records, and test in deployed Supabase. This upgrade is a database foundation, not a complete customer QR ordering feature.
