# Tables Upgrade 202 — Assignment capacity indicators

- Eligible worker RPC now returns `max_active`, `remaining_slots`, and `capacity_state` based on current per-responsibility workload settings.
- Manager reassignment picker displays available / nearly full / at capacity states and active-job counts.
- Workers at capacity remain visible but cannot be selected in the Flutter UI.
- Server-side workload trigger (Upgrade 201) remains the authoritative enforcement against stale data and concurrent assignments.
- Existing notifications, audits, and manager permissions remain intact.

**Status:** ZIP validated; Flutter compilation, Supabase migration application and live concurrency tests have not been run. **Section 02 Tables: 81% estimated**, not deployment verified.
