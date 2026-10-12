# Dashboard Coding Upgrade 34 — Explainable operational insights

Added `lib/screens/dashboard/dashboard_insights.dart` and integrated its read-only
panel into the Dashboard. It surfaces suggestions ONLY from nonnegative, finite,
server-provided numeric metrics. Missing values never become zero or fake alerts.
Suggestions show the source metric, do not execute changes, and are sorted by
urgency. No generative AI service is connected; this is a rule-based foundation.

Next: real-time refresh/offline safeguards, full review, design previews.
Verification deferred: no Flutter compilation, unit tests, or Supabase deployment.
