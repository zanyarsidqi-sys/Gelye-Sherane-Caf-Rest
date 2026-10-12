# Upgrade 691 — Exact inventory movement history

- Fixes stock history audit rendering for PostgreSQL bigint deltas.
- Uses signed integer parsing rather than floating-point conversions, preserving exact values.
- Malformed/fractional/overflowing values show Unknown movement, never zero.
- No schema changes.
- Validation: static regression tests; Flutter compilation and live Supabase testing outstanding.
