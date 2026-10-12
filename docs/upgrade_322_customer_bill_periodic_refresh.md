# Upgrade 322 — Customer bill periodic reauthorization

- The customer bill preview now refreshes every 60 seconds while the screen is mounted, the app is visible, and no refresh is in progress.
- Each refresh reuses the visit-scoped Supabase RPC, clears the previous snapshot, and rejects outdated responses.
- The timer is cancelled on screen disposal.
- The screen explains the automatic refresh interval.
- This is a gross order preview, not a reconciled outstanding balance.

Verification: static code checks and ZIP integrity only. Flutter compilation and live Supabase testing have not been performed.
