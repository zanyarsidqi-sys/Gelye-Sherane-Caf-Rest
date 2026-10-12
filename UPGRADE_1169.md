# Upgrade 1169 — Kitchen view changes invalidate handover confirmation

Changing the Kitchen search query or sort order now invalidates pending
confirmation tokens and releases the confirmation lock. This prevents
confirming a handover under a stale view after reordering or filtering.

Flutter compilation and live Supabase verification are deferred.
