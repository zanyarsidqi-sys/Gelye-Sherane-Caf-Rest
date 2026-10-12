# Dashboard Upgrade 116 — Cash-only release button connected

The Dashboard table-details screen now contains a **real, confirmed**
"Request cash-only table release" action calling the Upgrade 115
`gs_release_cash_only_table_visit` transaction RPC with the server-issued
visit ID. No client-calculated payment or cleaning flag authorizes release.

The server still rejects unverified, mixed, provider, credit, refunded or
owner-comped orders; incomplete physical tasks; and unauthorized staff.
Errors leave the table unchanged. Successful responses disable repeat taps.
The UI does not claim to support general checkout.

**Important:** Source-code integration only. The Upgrade 115 RPC and
schema require a full compatibility/security/concurrency review and live
Supabase deployment before this button can safely be enabled in production.
Flutter compilation and device testing are not performed here.
