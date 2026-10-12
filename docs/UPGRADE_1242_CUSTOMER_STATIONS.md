# Upgrade 1242 — Customer and station visibility / management

- Kitchen tab now exposes **Product Routing** beside Stations, using existing server-authorized routing RPCs.
- Stations panel now offers **Add Station**, requiring an existing printer or POS device ID. The new SQL RPC enforces authenticated MFA (AAL2), kitchen edit permission and an active station supervisor assignment, and checks the printing target exists before creating the station.
- Existing Kitchen item details already display `guest_label` (fallback `guest_number`) and `station_name` when provided by the authorized detail RPC. Those labels are **not guaranteed on every summary card** and cannot be invented when no customer name was captured.
- Product routing changes affect future dispatch; do not silently reroute already printed or queued historical tickets.
- Station account provisioning, employee assignments and device login remain separate existing administrative workflows. Station creation does **not** automatically create a credential or attach a new printer.
- Known security issue for later review: the older `gs_kitchen_station_ticket_details` RPC only checks broad Kitchen permission, not explicit station assignment. Do not expose it as a station-scoped endpoint without fixing authorization.
- Not verified: Flutter compile, live Supabase migration, actual POS/printer behavior. These are explicitly deferred.
- Upgrade 1241 was a visual preview only; this ZIP advances from the last verified full-project source archive, 1240.
