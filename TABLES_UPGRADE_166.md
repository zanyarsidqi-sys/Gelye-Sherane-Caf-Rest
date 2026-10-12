# Tables Upgrade 166 — Finance approval preparation in Flutter

The Tables bill-transfer review dialog now invokes the server-side
`gs_prepare_table_bill_transfer_approval` RPC and displays its review-ready
state, next required action, reviewer ID and check timestamp. It refuses
to display an approval result if the RPC unexpectedly reports
`execution_permitted` other than `false`. The UI contains **no Approve or
Execute button**. All checks are read-only and do not modify finances.

Progress: Tables **55% estimated**, 7/20 major steps complete, 13 remain.
ZIP integrity verified. Flutter compilation and live Supabase testing pending.
