# Upgrade 1304 — Dashboard seven-day chart label fitting

- Prevent valid large order counts from overflowing the narrow seven-column iPhone chart.
- Fit the abbreviated day labels within their chart cells when display scaling is increased.
- Keep the full date and count in the existing accessibility Semantics label.
- No changes to Supabase requests, financial calculations, permissions or other sections.

## Verification
Archive integrity, original-file preservation, and source assertions were checked. Flutter compilation and device testing remain unverified because the SDK is not installed.
