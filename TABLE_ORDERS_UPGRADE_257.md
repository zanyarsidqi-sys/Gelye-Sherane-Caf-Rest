# Upgrade 257 — QR-scoped customer menu price quote

Added `gs_public_table_menu(p_token uuid)` as a read-only Supabase RPC.
It resolves only an occupied table with a valid revocable QR token, checks the website menu switch, and returns product names and table-mode-aware IQD price quotes. Normal/Tourism and configured Admin discount are supported. Owner mode fails closed until an owner price source is verified. No guest data, order history or bills are returned.

**Not implemented:** secure visit-scoped customer order submission, per-customer split billing, QR browser UI, server-side rate limits, and live Flutter/Supabase tests. QR possession alone must not authorize financial actions.

Apply the migration only after reviewing it against the deployed database schema.
