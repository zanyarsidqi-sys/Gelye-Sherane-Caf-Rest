# Phase 3 — Customer activity workspace

- Read-only recent order activity in Customers section.
- Search by order ID/destination and filter Normal/Tourism.
- Uses existing gs_orders query and employee section authorization; no schema changes.
- Does not claim to provide customer identities, profiles, unique counts, or order history by customer.
- Requires existing gs_orders migration, Supabase RLS, and testing on Windows tomorrow.
