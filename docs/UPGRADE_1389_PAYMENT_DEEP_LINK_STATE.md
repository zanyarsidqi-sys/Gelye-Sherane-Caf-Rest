# Upgrade 1389: Dashboard deep-link and card filter isolation

- Honor `initialFocus` in `initState` for `standing` or `pending`; invalid focus falls back to Standing Cash.
- Preserve the parent application's Navigator, section navigation, Cash Reconciliation and existing Supabase RPC calls.
- Reset the Standing Cash server-eligibility filter when switching either card so its state cannot leak into another card.
- Do not infer missing employee, payment subtype or date fields from partial financial RPC responses.
- Pending Payment Pay remains blocked; no new payment authorization or financial mutations added.
- Source assertions and ZIP integrity checked; Flutter compilation, Supabase and screenshot testing unavailable.
