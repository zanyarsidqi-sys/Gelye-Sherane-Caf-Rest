# Tables Upgrade 157 — Guest move execution UI

- New read-only permission-checked `gs_list_pending_guest_moves()` RPC.
- Flutter Tables toolbar opens pending guest move requests.
- Financial/bill-transfer requests are shown but disabled for this action.
- Confirmation dialog states that **only guest counts** are moved.
- Calls existing `gs_execute_guest_count_only_move` and refreshes table status.
- Database remains authoritative for permission, capacity, conflicts and audit.

**Verification:** ZIP integrity and source insertion verified. Flutter compilation and
Supabase migration/runtime tests have NOT been performed. No bill transfer occurs.

**Tables progress:** 32% estimated; 7/20 milestones, 13 remaining.
