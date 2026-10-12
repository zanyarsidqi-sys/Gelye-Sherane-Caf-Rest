# Tables Upgrade 171 — Flutter Add / Remove Chairs

Implemented a chair adjustment dialog in `lib/sections/tables.dart` for
every table, displaying existing capacity and guests, +/- controls,
mandatory reason, cancellation and save. Save calls the Upgrade 170
`gs_adjust_table_chairs` RPC and refreshes table data.

The UI prevents reductions below the displayed guest count, but the
database RPC remains the authoritative concurrency and permission gate.
No order, payment, customer or visit is deleted by the chair operation.

Next tasks: validate SQL schema in live Supabase, chair history UI,
customer seat names, table-specific QR code printable/mobile flows,
normal/tourism pricing, arrival duration and historical date filters.

Expanded scope: **50% estimated**. 7/20 previous major milestones
complete; 13 remaining, plus newly expanded requirements. ZIP integrity
verified; Flutter build and live database tests pending.
