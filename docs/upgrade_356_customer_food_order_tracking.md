# Upgrade 356 — Customer food order tracking

- Added `gs_public_motel_food_order_status`, scoped to a currently valid guest session and room QR.
- Returns the guest session’s latest 50 food requests and server-recorded item/price snapshots.
- Added a manual-refresh `My Food Orders` panel in the customer QR screen.
- Refresh after successful food order submission; status progression is driven by existing employee/Kitchen actions.
- No automatic billing, delivery confirmation, kitchen ticket creation, or realtime push is claimed.
- Requires migration 356 after migrations 352–355.
- Flutter and live Supabase execution have not been tested in this environment.
