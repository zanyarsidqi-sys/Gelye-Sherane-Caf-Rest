# Phase 3 — Table transfer and reservation cancellation

- Authorized staff can transfer occupied tables to a free table with enough seats.
- Active table orders follow the transfer; existing charged item prices remain unchanged.
- The original table is released, and transfer is audited.
- Authorized staff can cancel pending or approved reservations; audit is recorded and the assigned table is released.
- Migration 024 must be applied after previous migrations.
- IMPORTANT: The reservable-table and live-table inventories are separate. Reservation collision checks rely on matching the numeric table label. Align these inventories before production.
- SQL, Flutter compilation and end-to-end concurrency testing remain outstanding.
- Historical overall implementation estimate remains 61%; not independently recalculated.
