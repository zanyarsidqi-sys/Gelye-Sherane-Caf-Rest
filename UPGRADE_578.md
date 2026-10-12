# Upgrade 578 — Employee-session-safe replacement recovery

- On app resume, re-read the signed-in employee’s device-local recovery pointer.
- Prevent delayed storage loads and server receipt responses from clearing a pointer after an employee session switch.
- Keep the original request identity and no-auto-retry policy.
- No Supabase migration required.

Verification: static tests only. Flutter compile, real authentication switching, and Supabase integration remain untested.
