# Upgrade 1210 — Table Orders replacement delivery notifications

Adds a durable, append-only notification on Kitchen replacement delivery events `accepted`, `picked_up`, and `delivered`. The trigger derives the order from the revision, rather than trusting client-supplied IDs. Table Orders employees with `can_view` permission can list notifications and mark their own read receipts. All table access is via permission-checked SECURITY DEFINER RPCs; direct table grants are revoked and RLS is enabled. The existing 15-second Table Orders screen refresh also refreshes notifications. No changes to corrections, invoices, inventory or delivery transitions.

Limitations: In-app polling only, no background push. Requires migration deployment and live Supabase verification, deferred by request.
