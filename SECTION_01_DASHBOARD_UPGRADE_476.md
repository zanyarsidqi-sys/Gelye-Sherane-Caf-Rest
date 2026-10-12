# Upgrade 476 — Dashboard weekly activity accuracy and usability

- Weekly order activity now validates server rows before charting; malformed rows are not interpreted as zero.
- Adds seven-day order count and busiest day from the same permission-scoped weekly RPC.
- Metric cards now show Restricted when the server supplies a null or nonnumeric metric, rather than displaying `null`.
- Preserves permission-aware summaries, credit restrictions, and all prior features.
- Dashboard remains 78% provisional coding progress pending requirements reconciliation; no Flutter compilation or live Supabase testing performed.
