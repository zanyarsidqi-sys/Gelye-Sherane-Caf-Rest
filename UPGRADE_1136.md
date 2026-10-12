# Upgrade 1136 — Kitchen motel food queue session isolation

- Track active employee identity and listen for authentication changes.
- Invalidate previous employee queue data and clear action busy state on account switch.
- Ignore stale in-flight operation UI updates after account changes.
- Prevent actions when signed out or request ID is missing.
- Tolerate malformed individual item values in queue description.

Verification: static regression tests only; Flutter compile and live Supabase testing unavailable.
