# Upgrade 1161 — Kitchen item requests bound to queue generation

Item fetches now carry the queue generation that created them and reject
results after a refresh, filter change, or employee account switch.
This closes a same-employee sign-out/sign-in race where an old request
previously could populate the refreshed item preview.

This is a source-level improvement only; Flutter and Supabase live
verification remain deferred.
