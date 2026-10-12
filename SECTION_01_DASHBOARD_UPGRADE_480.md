# Upgrade 480 — Dashboard permission-scoped snapshot export

Adds a copy-to-clipboard operational snapshot to Section 01. The export includes only the eight read-only metrics already returned by `gs_dashboard_operational_summary`, labels restricted or missing metrics as unavailable, includes the server timestamp, and excludes financial balances and credit data. Clipboard failures show an error. No new database permissions or migrations are needed.

**Progress:** Dashboard 83% provisional development estimate (not independently verified); Tables 94% historical; Table Orders 69% historical; Motel Orders 91% estimated.

**Verification outstanding:** Flutter analyze/build, Supabase migration deployment, permission/RLS testing, operational reconciliation, iPhone/Windows device testing. Clipboard content is sensitive operational information; users should paste it only into approved destinations.
