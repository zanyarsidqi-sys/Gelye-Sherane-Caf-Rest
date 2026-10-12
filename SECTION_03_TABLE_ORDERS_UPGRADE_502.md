# Upgrade 502 — Table Orders mutation serialization and audit time labels

- Employee service-job refresh is deferred while a job mutation is active.
- After success or failure, the job queue reloads from permission-scoped Supabase RPCs, instead of retaining potentially stale action state.
- Manual refresh is disabled during job mutations and item fulfillment transitions.
- Item timelines label event times as Event; order revisions label modification times as Changed; order creation remains Ordered. All are displayed in Iraq local time.
- Existing sections, migrations and functionality are retained.

## Verification limitations
Archive integrity checked; Flutter compile and live Supabase tests not performed.
