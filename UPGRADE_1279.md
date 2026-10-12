# Upgrade 1279 — Dashboard startup refresh coordination

- Mark initial overview and weekly requests as in-flight before dispatching them.
- Share refresh settlement/queued-day handling with manual and automatic refreshes.
- Prevent a fast business-day change during initial load from overlapping RPC batches.
- Keep original futures for existing error/loading UI; settlement catches errors only for lock coordination.
- No schema, permission or card changes.
- Static assertions and archive checks passed; Flutter SDK and live Supabase were unavailable.
