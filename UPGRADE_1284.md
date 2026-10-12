# Dashboard Upgrade 1284

- Added a 20-second timeout to the primary overview and weekly trend Supabase RPCs. A hung network request now settles with an error so the coordinated refresh lock and pull-to-refresh waiter can be released and the existing retry UI becomes available.
- Added an 8-second timeout to the optional operational-metrics RPC. It retains the pre-existing best-effort behavior: an optional failure does not discard successfully retrieved overview figures.
- Preserved existing RPC names, permissions, metric cards, navigation, and date pinning.
- Static source and archive verification performed; Flutter SDK and live Supabase unavailable.
