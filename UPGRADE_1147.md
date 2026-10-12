# Upgrade 1147 — Kitchen staging authorization preflight

Added `supabase/verification/kitchen_1147_access_readiness.sql` with eight read-only staging checks: function existence, authenticated RPC execute permission, anonymous and PUBLIC denial, guard-function access denial, and active item trigger. Run after migrations 1142–1144 and require every row to pass. This has NOT been run against Supabase.

Kitchen live acceptance: 0/5 verified. Flutter compilation: not performed. Next: 1148.
