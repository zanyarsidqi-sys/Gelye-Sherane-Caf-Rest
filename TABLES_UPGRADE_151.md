# Section 02 — Tables — Upgrade 151

Adds an **additive, reservation-aware server-side seating migration** replacing
`gs_open_cafe_table_visit` from the draft. It serializes seating with reservation
approval via advisory transaction lock and rejects seating when an approved
reservation is in its active time window. Capacity, cleaning, occupancy, active
visit, role permissions, and Normal/Tourism pricing are still checked.

**Important limits:** This is a conservative walk-in hold, **not** a reservation
check-in workflow. Reservation mapping relies on numeric `table_label` matching
`gs_cafe_tables.table_number`; the current schema does not enforce a complete
one-to-one mapping. Reservation holders cannot check in through this RPC yet.
Do not deploy before reconciling that mapping and testing on staging. The
legacy transfer function also needs replacement with visit-aware movement.
No live Supabase/Flutter execution was performed.

Dashboard paused at Upgrade 149; Section 02 ongoing; overall Phase 3
~54% estimated, not verified.
