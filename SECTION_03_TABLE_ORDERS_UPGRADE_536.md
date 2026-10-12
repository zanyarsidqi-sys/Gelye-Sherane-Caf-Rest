# Upgrade 536 — Flutter product replacement workflow

Added a searchable active-menu product selector on unaccepted table-order items. Employees must supply a correction reason and confirm before the UI calls `gs_replace_unaccepted_table_item` introduced in migration 535. Backend determines actual normal/tourism pricing and checks authorization, kitchen status, payments and invoices atomically. UI displays the server-returned IQD difference and refreshes the board.

Limitations: product catalog query is limited to 500 entries; no server-side search pagination yet. Flutter compile and live Supabase RPC testing have not been performed. Deploy migration 535 before using the feature. Existing board refresh remains required to observe updates.
