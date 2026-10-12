# Upgrade 486 — Dashboard cash collection integrity

- Validate cash collection response timestamps and all available ledger fields before presenting results.
- Add a combined cash collection indicator only when both separate ledger amounts and receipt counts are accessible.
- Keep combined totals labelled **unreconciled cash collections**, not revenue, profit or verified accounting.
- Correct misleading Dashboard footer that previously claimed cash was excluded even when the cash panel was visible.
- Preserve existing permissions and do not enable credit deductions.

Development progress remains **83% provisional**. Flutter compilation, live Supabase migration testing, and ledger reconciliation have not been performed.
