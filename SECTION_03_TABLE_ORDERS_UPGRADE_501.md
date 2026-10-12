# Upgrade 501 — Table Orders RPC safety and concurrency

- Validate positive integral order and item IDs before calling history, timeline, or dispatch RPCs.
- Disable unsafe history/edit affordances when data is unavailable.
- Serialize fulfillment transitions to avoid concurrent refresh/transition races.
- Queue refreshes during an in-flight transition and run them when safe.
- No new Supabase permissions, data models, or migrations.

## Verification boundaries
Archive integrity is checked; Flutter compilation and live Supabase validation remain outstanding.
