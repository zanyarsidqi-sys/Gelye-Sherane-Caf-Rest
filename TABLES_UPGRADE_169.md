# Tables Upgrade 169 — Financial review audit history

Added permission-scoped read-only Supabase RPC
`gs_list_table_transfer_finance_reviews(bigint)` and a Flutter
**Review history** button in the bill-transfer review dialog.

Displays up to 100 immutable review records per transfer request,
including reviewer ID, timestamp, requested amount, blocker codes,
and explicit **execution permitted: No** status. Users without both
finance and table-order view permission are denied access.

Does not approve or execute a bill transfer. ZIP structure and file
uniqueness verified; Supabase migration execution and Flutter compilation
remain pending.

Tables: 61% estimated; 7 completed / 13 remaining major milestones.
