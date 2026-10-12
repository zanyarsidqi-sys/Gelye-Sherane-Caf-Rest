# Upgrade 1301 — Accessible weekly cash rows

- Wrap each weekly cash detail row in one descriptive Semantics node so VoiceOver and TalkBack announce business date, order count and cash received together.
- Use "cash unavailable" for permission-hidden/null amounts, not zero.
- Exclude nested visual labels from semantics to prevent duplicate announcements.
- No Supabase, permission, data or financial calculation changes.

Validation: archive integrity, source assertions and unchanged-file byte comparisons. Flutter compilation and device screen-reader verification remain pending.
