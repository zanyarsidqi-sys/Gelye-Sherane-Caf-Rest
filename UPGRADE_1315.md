# Upgrade 1315: Verify receipt belongs to selected order

Dashboard: the Recorded Cash card explicitly directs employees to verify order receipts in Payments Management.

Payments Management: receipt display and copy now require a positive integral order ID matching the selected ledger order, in addition to existing receipt ID, amount and date validation. This adds client-side defense against cross-order receipt misassociation; server-side RLS and RPC checks remain unchanged.

Verification: archive integrity, unchanged-file byte comparison, and source assertions. Flutter compilation, Supabase integration and device tests remain outstanding.
