# Upgrade 1374 — authorized cash reconciliation order lookup

- Added a live order-ID substring search against `order_id` already returned by `gs_cash_reconciliation`, combined with existing cash/receipt/difference filters.
- The bottom total and record count use the exact filtered rows.
- Disable tapping orders with absent or nonpositive IDs.
- Make the total footer responsive for narrow phone layouts.
- No new RPC, payment, official invoice printing, or saving action was enabled.
- Static assertions and ZIP CRC passed; Flutter compilation and live Supabase tests pending.
