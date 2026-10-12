# Upgrade 483 — Dashboard cross-section consistency

- Validate server timestamp in the Dashboard RPC response; reject missing, invalid or implausibly future timestamps.
- Add read-only checks for daily order totals versus table+motel subtotals, occupied versus total tables, and tourism versus occupied tables.
- Treat inaccessible metrics as unknown, never zero or a passing test.
- No financial or credit totals added.
- Development estimate stays 83% until substantive financial and navigation requirements are completed.
- Flutter compilation and live Supabase verification not performed.
