# Upgrade 1289 — Dashboard RPC response validation

- Validate that the primary overview RPC returns a map before converting it.
- Reject invalid map keys with a controlled FormatException instead of an unchecked cast error.
- Show a safe, actionable invalid-response message without leaking raw server payloads.
- Preserve all existing Dashboard features, authorization, optional metrics, refresh coordination and other project files.
- Static source checks and ZIP integrity verified; Flutter SDK and live Supabase tests unavailable.
