# Upgrade 1166 — Kitchen error-state retry

Added a visible **Retry loading kitchen orders** action to the live Kitchen queue error screen. The retry calls the existing session-safe `_refresh()` routine, invalidating cached items and stale confirmations. This addresses the dead-end error state when the network temporarily fails.

Source-level regression tests only. Flutter and live Supabase acceptance remain deferred.
