# Upgrade 180 — Priced Takeaway & Delivery Draft Items

Added a restricted Supabase RPC that snapshots menu product names and
**server-selected** Normal/Tourism prices for each counter-request item.
The Flutter counter screen can select a pending request, enter an existing
menu product ID and quantity, choose pricing mode, and add a priced draft.
A separate RPC calculates the draft total without collecting money.

The current entry uses numeric product IDs, **not** a menu browser or barcode
scanner. The request is still an intake draft; not an order, invoice, payment,
kitchen ticket, stock deduction, employee delivery assignment or notification.
Product availability, permission and pending-request checks occur server-side.

No live Supabase migration or Flutter build performed. ZIP integrity verified.
Tables ~60% estimated; Table Orders functionality remains incomplete.
