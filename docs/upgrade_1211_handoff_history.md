# Upgrade 1211 — Replacement handoff history and consistency

Added read-only Table Orders RPCs `gs_table_replacement_handoff_history` and `gs_replacement_handoff_consistency`. Both require authenticated Table Orders viewing permission. History includes employee actor, assigned recipient, timestamp and status event. Diagnostics flag impossible or missing delivery task states; they never auto-modify invoice, payment, correction or delivery records.

The Table Orders replacement progress panel displays an expandable handoff history and consistency warnings. Polling remains 15 seconds. No push notifications are added.

Verification: static checks and ZIP integrity only. Flutter compilation and live Supabase testing intentionally deferred.
