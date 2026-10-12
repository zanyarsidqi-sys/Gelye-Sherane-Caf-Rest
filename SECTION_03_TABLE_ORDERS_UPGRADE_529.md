# Upgrade 529 — Server-priced quantity correction preview

Added a read-only, permission-scoped Supabase RPC that previews the previous line total, corrected line total and IQD difference from the stored unit price. The Flutter quantity editor requires this server response and shows the financial change before confirmation. It rejects invalid or unavailable previews. The preview checks order eligibility, kitchen tickets, locked invoices and existing payment evidence; the existing mutation still rechecks conditions transactionally, preventing reliance on a potentially stale preview.

Deploy `20261010_529_quantity_financial_preview.sql` after 528. ZIP integrity verified; Flutter compilation and live Supabase execution not verified.
