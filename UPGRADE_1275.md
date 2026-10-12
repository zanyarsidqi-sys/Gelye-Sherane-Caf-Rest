# Upgrade 1275 — Dashboard request-date error isolation

- Prevent an in-flight request for a previous business day from setting the currently selected day’s refresh-error warning.
- Preserve existing successful-snapshot timestamps, queued refreshes, permissions, metrics, and navigation.
- Verification: archive integrity and targeted source assertions only; Flutter runtime and Supabase tests remain pending.
