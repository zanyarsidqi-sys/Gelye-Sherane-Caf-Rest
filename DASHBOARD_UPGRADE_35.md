# Dashboard Coding Upgrade 35 — Lifecycle and refresh reliability

- Dashboard now observes Flutter application lifecycle. Its 30-second polling
  pauses when backgrounded and refreshes on returning to the foreground.
- Refreshes remain single-flight; a refresh requested while an existing request
  is running is coalesced into one follow-up, so selected-day changes cannot
  be silently dropped during a slow RPC.
- Date changes during a request trigger a new fetch for the selected day.
- Lifecycle observer is unregistered on disposal.
- No simulated offline orders, optimistic financial writes, or fictitious
  real-time subscriptions were introduced. Existing local preference fallback
  and server-derived financial values are preserved.

Still pending: actual offline order queue/conflict resolution and verified
Supabase Realtime subscriptions. Flutter compile and device tests deferred.
Next: Upgrade 36 review and iPhone/Windows concept previews.
