# Upgrade 1269 — Dashboard stale-data warning

When a Dashboard FutureBuilder reports a refresh error while retaining usable authorized data, display a prominent accessible warning that figures may be outdated and provide a retry action using the existing `_refresh` callback. No data permissions or metrics were changed.

Verification: ZIP integrity and static source checks only; Flutter and Supabase runtime not tested.
