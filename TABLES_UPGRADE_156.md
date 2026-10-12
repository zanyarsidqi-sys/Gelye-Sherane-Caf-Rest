# Tables Upgrade 156 — guest-count-only move execution

Added a narrowly scoped SQL RPC `gs_execute_guest_count_only_move(request_id)` and
immutable execution audit. The RPC serializes request, visits and tables, rechecks
capacity and guest counts, prevents duplicate application and conflicting pending
moves, and updates both visit/table counts in one transaction.

**Safety restrictions:** rejects requests with `move_bill=true`; rejects moving the
last guest; leaves orders, payment history, tourism prices, reservations and
visit identities unchanged. This is **not** bill transfer, table joining or
reservation reassignment. Deployment requires checking local schema, reservation
policy, permissions and UI integration. No live PostgreSQL execution was possible.

Tables estimate: 29%, 6 of 20 planning milestones complete, 14 remain. These
milestones are not equal effort and are not verified production acceptance.
