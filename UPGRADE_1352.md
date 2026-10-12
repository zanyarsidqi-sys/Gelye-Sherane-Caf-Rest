# Upgrade 1352 — Pending Payment motel invoice integrity

Added a permission-gated, read-only UUID-native diagnostic for posted motel food finance invoices. It compares invoice totals and source counts against lines, and checks cash settlement count, totals, and status consistency. It explicitly does **not** authorize collection or confirm full settlement across channels. Existing Standing Cash functionality is unchanged.

Validation: source contract test and ZIP integrity; no live Supabase or Flutter compilation.
