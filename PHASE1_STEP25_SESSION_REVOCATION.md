# Phase 1 Step 25 — Session revocation

Adds auth event monitoring, periodic 60-second authorization refresh, resumed-app refresh, immediate local lock on logout, and stale-response identity checks.

**Limitations:** Static verification only. Revocation is not instantaneous in an already-open section; all privileged server requests must enforce RLS. Flutter compilation and live Supabase verification remain pending.
