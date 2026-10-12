# Upgrade 1291: Reject empty Dashboard overview responses

- Validate the main Supabase overview RPC returns a nonempty map. An empty map is not a valid snapshot and must not silently appear as a successful business day.
- Route an empty response through existing FormatException handling, showing a safe message and the existing retry UI.
- Remove redundant `result.isNotEmpty` from the success timestamp guard because `_load` now rejects empty snapshots.
- Preserve all other Dashboard and project files.

Verification: archive integrity, retained entries, unchanged-file byte equality and static source assertions. Flutter SDK and live Supabase not available; no compilation or runtime verification claimed.
