# Upgrade 308 — Customer call workflow corrections

- Fixed first-load staff notification false positive: a waiting request already in the queue on first load no longer produces a misleading “new request” snackbar. Subsequent newly detected waiting calls still alert while the queue is open.
- Added waiting/active counts and specific employee guidance for delayed orders and extra chairs.
- Added customer “Make another request” after completed/cancelled/unavailable status; server-side duplicate and rate limits remain enforced.
- No push notifications, database migration or production deployment in this upgrade.
- Flutter compilation and Supabase integration not tested in this environment.
