# Upgrade 251 — Tables display accuracy

- No custom table-name fields; tables retain their numeric identifiers.
- Show customer names and available visit times from the authenticated active-visit RPC.
- Read each active table's money summary via the existing permission-protected `gs_table_item_money_overview` RPC and display a recorded amount only when its returned JSON exposes a known amount field. No fake prices or zeros.
- Unavailable amounts are explicitly labeled; the existing Items & money detail remains available.
- No new backend mutation or unsafe time-editing endpoint has been introduced. Editable times require review of the existing reservation/visit update RPCs.
- These are source-code edits only; Flutter compile and Supabase integration have NOT been run. Section 03 remains next after Tables validation.
