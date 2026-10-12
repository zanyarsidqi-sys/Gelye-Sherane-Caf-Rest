# Upgrade 1326 — Payments / Finance batch

- Added two explicitly differentiated Dashboard cards: Standing Cash (live unpaid active café visits) and Pending Payment (unpaid online/motel orders).
- Both use existing financial card View Details and Payments Management permission-gated navigation; values remain unavailable until the authorized dashboard RPC supplies a metric.
- Added metric definitions and an expandable Payments Management contract describing inclusion/exclusion, partial payments, prepaid packages and no double counting.
- No database migrations or unverified financial computations were invented.
- Still required: backend RPCs, historical snapshots, date/time and employee filters, Flutter compilation, device tests, and live Supabase verification.
