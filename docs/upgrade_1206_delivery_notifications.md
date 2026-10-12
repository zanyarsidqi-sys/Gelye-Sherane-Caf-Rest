# Upgrade 1206 — Replacement delivery alerts and escalation

- Permission-scoped employee counts; supervisors see the full station backlog, workers see their own tasks and accessible unassigned work.
- Supervisor-only escalation action stores durable, deduplicated overdue alerts in a protected table.
- Escalation inbox is supervisor-only. Reassignment or status progression resolves old alerts on next escalation action.
- Flutter Kitchen correction panel polls every 15 seconds while open, displays status counts and supervisor escalation inbox.
- No OS push notifications or background job scheduler. Escalations are generated when a supervisor invokes the action, not automatically while the app is closed.
- Source-only upgrade; Flutter compilation, migration execution and live Supabase verification deferred.
