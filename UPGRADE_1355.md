# Upgrade 1355 — Pending Payment finance triage

Adds a permission-inheriting, read-only triage RPC wrapping the existing motel invoice integrity diagnostic. Returns a safe next review action and severity; explicitly **never** authorizes collection or confirms settlement. Standing Cash code and all existing archive entries are unchanged.

Testing: ZIP CRC and static contract test. No live Supabase or Flutter execution.
