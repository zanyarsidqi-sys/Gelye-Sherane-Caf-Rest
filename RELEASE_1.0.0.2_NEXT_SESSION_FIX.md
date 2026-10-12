# Release 1.0.0.2 development-only update

- Removed a nested `CafeApp` created on dashboard logout, which could stack multiple global footers.
- Saved-session restore now compares stable JWT `session_id` across Supabase token refresh, rather than requiring the old access token to remain byte-identical.
- Existing saved-device duration selection, AAL2 MFA, employee profile and permission checks remain mandatory.
- No live deployment, production database changes, or browser notification dispatch performed.
- Requires Flutter compilation and device/browser end-to-end testing before release approval.
