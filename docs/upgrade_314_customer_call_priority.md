# Upgrade 314 — Customer request priority and queue usability

- Employee call queue shows elapsed time rather than raw timestamps.
- Urgent requests (long-wait reports and unanswered requests older than five minutes) are visibly flagged and sorted first, with a toggle to disable priority ordering.
- Existing authorization, acceptance workflow, and eight-second polling are unchanged.
- Customer request details for extra chairs are capped at 300 characters including the automatically generated prefix to align with database constraints.
- This is an **in-app** prioritization indicator, not an automated supervisor escalation or push notification.
- Flutter compilation and live Supabase testing remain unverified.
