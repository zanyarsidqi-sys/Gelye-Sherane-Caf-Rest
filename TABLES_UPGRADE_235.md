# Tables Upgrade 235 — Preparation Instructions

Adds a nullable, 500-character preparation instruction field to each order item. Staff with table-order or motel-order edit permission can set instructions via `gs_set_order_item_preparation_instructions` while the order is `new`. Instructions are locked after acceptance and snapshotted when station tickets are created. `gs_get_station_ticket_content` now returns the actual station-specific notes. No printer drivers or physical printing are added.

Apply migration 235 after 234. Integration into the order-entry UI and actual physical printing remain pending. ZIP structural verification only; Flutter and Supabase not run.
