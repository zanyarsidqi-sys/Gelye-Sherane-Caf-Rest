# Upgrade 310 — Customer request type alignment

Verified that migration 303 defined a CHECK constraint and an RPC allowing only five basic employee call types, while the Flutter customer screen exposes five additional request types. This upgrade replaces the CHECK constraint and request RPC to support all ten options, with server-side validation of specific-order notes and extra-chair counts. Also corrects staff queue empty/loading/error messaging and waiting/being-handled counts.

**Not production verified:** Supabase migrations were not applied to a live database; Flutter SDK is not installed in this environment. The staff queue still uses foreground polling, not background push. Existing migrations 304–309 must be reviewed together before production deployment.
