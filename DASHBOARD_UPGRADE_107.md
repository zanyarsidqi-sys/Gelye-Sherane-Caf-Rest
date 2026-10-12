# Dashboard Upgrade 107 — Service-task completion action

Adds an **actual state-changing RPC** for visit-linked table cleaning and
shisha pickup tasks. An authorized employee can mark an eligible task
`completed`; repeat submissions return the same task ID.

Strict requirements: visit already in `cleaning` status, table occupied and
flagged for cleaning, confirmed guest departure, task explicitly linked to
that visit, and `tables.can_edit` permission. Cancelled or unlinked tasks
cannot be completed. The table **remains occupied**; neither cash settlement
nor physical table release is implied.

Integration limitation: existing checkout is deliberately disabled and no
trusted transition into visit `cleaning` is available yet, so this RPC is
**not currently reachable through the full end-to-end checkout flow**.
It must be deployed only after schema review, settlement implementation,
and proper transition into cleaning stage. No Flutter compilation or live
Supabase execution has been performed.
