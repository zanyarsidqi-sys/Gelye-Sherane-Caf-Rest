# Upgrade 516 — Table Orders data and handoff integrity

- Fail closed on malformed order IDs, nonpositive or non-integer quantities, table numbers, and missing product names in the permission-scoped order board.
- Manual kitchen handoff now requires a fresh (<= 2 minutes) board and is disabled during instruction editing.
- Handoff excludes malformed quantities and explicitly warns that the backend order board caps responses at 500 records.
- No quantity editing or price mutation was enabled; these require a transactionally safe, audited backend workflow.
- No new Supabase migration. Flutter compilation and live Supabase tests not performed.
