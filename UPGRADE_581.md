# Upgrade 581 — Recovery load ordering and logout safety

Section 03: fixes a race between device-local recovery loading, account changes, and a newly submitted replacement.

- Latest asynchronous load wins; stale responses are ignored.
- Logged-out sessions clear the visible pending pointer.
- A background load cannot overwrite an in-flight replacement pointer.
- Dispose invalidates outstanding recovery reads.
- No database migration required.

Static tests only. Flutter compilation and live Supabase integration have not been performed.
