# Upgrade 494 — Dashboard server-clock financial snapshot validation

- Seven-day cash report dates are now validated against the Supabase `as_of` timestamp rather than relying solely on the device clock.
- Rejects snapshots older than five minutes or more than two minutes in the future, reducing stale reports and clock-skew errors.
- Clipboard export uses the same server-defined Iraq business day and freshness requirements.
- Removed a duplicated vertical spacer in the cash reporting layout.
- Credit deductions remain disabled; cash figures remain unreconciled and permission scoped.
- No new migration. Flutter compilation and live Supabase verification still required.
- Section 01 progress remains 84% provisional.
