# Upgrade 1266 — Dashboard refresh-state safety

- Avoid hiding already-received authorized Dashboard figures behind a loading indicator when the connection is still transitioning.
- Show the error recovery card only if the request has failed and no snapshot data is available.
- Preserve all other Dashboard and Supabase behavior.

Static assertions passed. Flutter SDK and live Supabase were unavailable for runtime verification.
