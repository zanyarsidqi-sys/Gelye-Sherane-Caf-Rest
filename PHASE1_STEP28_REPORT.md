# Phase 1 Step 28 — Navigation and session races

- Invalidate cached management permissions before opening a route
- Refuse navigation while authorization review is already in progress
- Require same authorized user and no logout recovery before navigation
- Do not reverify protected route after signout
- Disallow asynchronous protected-route unlock while app is backgrounded

**Offline only:** Flutter compilation and live authentication remain pending.
