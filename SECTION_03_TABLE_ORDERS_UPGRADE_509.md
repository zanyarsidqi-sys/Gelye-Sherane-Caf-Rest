# Upgrade 509 — Secure pre-acceptance instruction editing

- Connects the Table Orders edit action to existing audited, optimistic-concurrency RPC from migration 261.
- Adds permission-scoped instruction retrieval RPC; avoids exposing unrestricted order rows.
- Limits editing to unaccepted items, with a 500-character field and backend validation.
- Reloads the board after success or rejection; other editing (quantity/product) remains unavailable.
- Not verified in Flutter compiler or live Supabase. Apply migration 509 after previous migrations.
