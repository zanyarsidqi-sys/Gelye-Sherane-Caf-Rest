# Upgrade 481 — Dashboard operational data availability

- Added an in-dashboard per-section data availability overview for Table Orders, Motel Orders, Kitchen and Tables.
- Only uses the existing permission-scoped `gs_dashboard_operational_summary` response. No new privileged queries or Supabase migrations.
- Validates that required counters are nonnegative finite integers before claiming availability. Missing/restricted fields are never interpreted as zero.
- This is an operational data diagnostic, not proof of server health, financial accuracy, or completed testing.
- Dashboard development progress remains **83% provisional** until financial KPI and cross-section acceptance criteria are implemented.
- Flutter CLI and live Supabase were unavailable in this environment; compilation and integration tests not performed.
