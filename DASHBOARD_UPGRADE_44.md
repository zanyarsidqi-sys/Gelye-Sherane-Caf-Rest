# Dashboard Upgrade 44 — Safe post-checkout cleaning foundation
- Draft RPC `gs_mark_table_departed_for_cleaning` requires explicit cashier confirmation that guests departed.
- Server independently checks all linked orders are served/cancelled and every served order fully paid in cash ledger.
- Sets cleaning_needed, keeps table occupied/unavailable, creates a deduplicated urgent cleaning task.
- Optional staff-confirmed shisha pickup creates separate task; NOT automatic product detection yet.
- Replaces legacy table update RPC with an additional cleaning-needed release guard.
- Strictly CASH-ONLY: noncash verified settlements cannot pass until integrated with verified payment ledger.
- **Important limitation:** historical orders are not grouped by table visit/session; checkout may be blocked by previous orders. Add visit/session IDs before production.
- Cleaning completion and authorized table release are NOT implemented yet.
- SQL is NOT deployed or tested. Requires review of all existing migration dependencies.
