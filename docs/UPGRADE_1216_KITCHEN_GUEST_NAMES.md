# Upgrade 1216 — Optional per-item customer names in Kitchen

- Existing `gs_order_items.guest_label` remains optional; no new billing columns or financial calculations are changed.
- Both station ticket item details and full Kitchen order item details display `Customer: <name>` when available.
- When an explicit guest number is provided by the caller, display `Guest N`; otherwise use `Table Order` (never invent a guest number).
- Names are shown per product line rather than once per table.
- Station and order detail RPCs already select guest_label from the original order item. Replacement and delivery summary RPCs do not all expose per-item guest labels; this is **not** a claim that all downstream views now display them. A further schema/RPC integration pass is required for full end-to-end propagation.
- Source-only checks passed. Flutter compilation and Supabase live tests remain deferred.
