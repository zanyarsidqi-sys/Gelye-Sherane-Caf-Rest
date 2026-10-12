# Upgrade 512 — Table Orders board integrity and stale-action protection

- Validate server order-board response type, positive integer item IDs, unique item IDs, and recognized fulfillment statuses before displaying or enabling actions.
- Fail closed on malformed responses rather than presenting ambiguous orders.
- Guard fulfillment and instruction editing against stale row snapshots not present in the current authorized board.
- Add request-generation guard to prevent outdated asynchronous responses from mutating a newer board or disposed widget.
- No new database migration; quantity/product edits remain disabled pending transactional accounting, inventory, ticket, and concurrency safeguards.
- Flutter compilation and live Supabase verification not performed in this environment.
