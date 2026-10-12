# Upgrade 579 — Employee-session boundary checks

## Change
- Cross-device replacement receipt history no longer presents a response after the authenticated employee changes.
- Manual request-ID lookup captures the initiating employee before the dialog, rechecks identity after server responses, and prevents a delayed receipt from clearing another employee's pending recovery state.
- Product replacement commit and read-back verify the original employee session before interpreting the response or clearing recovery state.
- No new migration. All prior files preserved.

## Verification limits
Static source regression tests only. Flutter compilation and real Supabase multi-session tests are still required. This is not a claim of production readiness.
