# Upgrade 1171 — Cancelled Kitchen order visibility

Added a Cancelled filter to the Kitchen live queue, and included cancelled
orders in the status summary. This aligns the UI with the existing database
status and the terminal-state integrity guard from Upgrade 1170. Cancelled
orders remain read-only: the status action switch does not permit advancement.

The filter is server-side before pagination, so cancelled orders can be
inspected even when the overall order history exceeds the safety cap.

Source-level tests only; Flutter compilation and Supabase verification deferred.
