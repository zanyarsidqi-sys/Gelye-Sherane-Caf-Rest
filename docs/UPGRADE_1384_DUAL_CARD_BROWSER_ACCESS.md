# Upgrade 1384 — Dual-card browser visibility

- Fixed an unclosed `ListTile` in PaymentsManagementPanel build.
- Dashboard Standing Cash deep link now displays BOTH Standing Cash and Pending Payment panels, with Standing Cash first.
- Pending Payment deep link already displays both, with Pending Payment first.
- Existing app navigation and all section files remain unchanged. Dashboard deep link remains inside the existing Navigator and does not replace the application shell.
- No new payment authority or Supabase RPCs. Pending Payment collection remains blocked.
- Static assertions and archive integrity checked; Flutter compile and live RLS tests remain unverified.
