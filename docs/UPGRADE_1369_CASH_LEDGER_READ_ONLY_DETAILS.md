# Upgrade 1369: cash ledger transaction drill-down

- A tap on an eligible cash reconciliation row now opens the existing read-only cash receipt details using the current permission-scoped RPC.
- Invalid order IDs cannot initiate the detail action.
- A visible tooltip documents why date/employee/cash-credit subtype filters cannot be claimed for this cash-only source without verified metadata.
- Existing cash status and warning filters and bottom-of-list cash total are preserved.
- No invoice printing, saving, settlement, or new permission added.
- ZIP CRC and source assertions checked; Flutter compile and live Supabase not tested.
