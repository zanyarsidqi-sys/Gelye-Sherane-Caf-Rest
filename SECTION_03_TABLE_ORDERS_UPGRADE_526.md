# Upgrade 526 — Quantity confirmation identity guard

- Before sending the correction RPC, verify the exact order item and order ID still match the displayed board.
- Verify original quantity, pre-acceptance status, uniqueness, freshness and load state after confirmation.
- Database optimistic concurrency and transactional pricing remain authoritative.
- No new migration. Flutter compilation and live Supabase verification outstanding.
