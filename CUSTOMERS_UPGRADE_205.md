# Upgrade 205 — Customer-linked table check-in

- Tables > Open visit now allows selecting an existing customer, creating a new customer with optional phone, or anonymous seating.
- `gs_open_cafe_table_visit_with_customer` atomically opens a table visit and links exactly one customer visit history record; existing table/cleaning/reservation rules remain in the original opening RPC.
- Customer creation and check-in roll back together if any validation fails.
- Adds a nullable `table_visit_id` FK and partial unique index to prevent multiple customer history entries for one table visit through this flow.
- Reservation check-in, historical manual entries, automatic verified spend ranking, deduplication by phone, and Flutter/Supabase runtime verification remain pending.
- Estimated: Tables 83%, Customers 20%. Not verified deployment.
