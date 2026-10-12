# Upgrade 521 — paginated order-board integrity

- Validate global descending (created_at, order_item_id) sequence across pages to detect shifted/overlapping offset pages. Fail closed rather than showing ambiguous fulfillment actions.
- Show actual page and item counts during multi-page loading.
- Clear loading progress at each refresh and preserve prior server permission checks.
- Offset pagination cannot guarantee a consistent snapshot under all concurrent inserts/deletes; a server-side keyset/snapshot approach remains recommended.
- No new migration. Flutter and live Supabase verification remain outstanding.
