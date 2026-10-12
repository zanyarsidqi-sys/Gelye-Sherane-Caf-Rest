# Upgrade 182 — Searchable menu selection for takeaway and delivery

Added product-name search and exact-barcode lookup in the counter-order
workspace. Results show menu product, barcode, normal and tourism prices;
selecting a result supplies its ID to the existing server-side priced-draft
RPC. The server remains authoritative for actual prices and active products.

Search is a permission-checked security-definer RPC, limited to 30 matches.
Barcode input works with keyboard-wedge scanners that type and press Enter;
phone-camera scanning is **not** implemented.

Still not a finalized sale: no kitchen ticket, payment, inventory adjustment,
delivery assignment or notifications. Live migration and Flutter compilation
have not been tested. ZIP integrity verified.
Tables 60% estimated; Table Orders improvements tracked separately.
