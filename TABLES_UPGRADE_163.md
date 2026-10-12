# Tables Upgrade 163 — Legacy transfer security hardening

**Critical safety fix:** The old `gs_transfer_cafe_table(integer,integer)`
RPC (from migration 024) could move an order's `destination` and change
table occupancy without transferring the authoritative table visit, order
ownership, financial allocations or reservation linkage. This creates
a dangerous inconsistency with later guarded table-visit workflows.

Upgrade 163 replaces this legacy RPC with an explicit rejection and revokes
client EXECUTE permissions. Existing **guest-count-only** request/execution
workflow remains separate and available subject to its own permissions.
Bill-transfer request and read-only review remain available; actual financial
transfer execution is still disabled.

Deployment caveat: Any older client using the legacy RPC will receive a
controlled error and must be migrated to the newer visit-aware workflow.
The SQL has not been executed against Supabase and no Flutter compilation
has been performed. The ZIP was checked for integrity.

Tables development: **49% estimated**; **7/20 major milestones complete**,
**13 remain**. This is a security-hardening increment, not a new completed
milestone.
