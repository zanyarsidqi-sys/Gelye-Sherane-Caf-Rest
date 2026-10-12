# Upgrade 357 — Motel food delivery assignment and tracking

Staff with motel_orders.can_edit can claim an unassigned ready food request. Only that same employee can advance ready -> on_way -> delivered. Backend row locks, permission checks, and audit records enforce the workflow. Delivered timestamp is recorded. Guest status RPC from Upgrade 356 displays on_way and delivered. This does not create room bills or confirm payment. Live Flutter/Supabase testing not performed.
