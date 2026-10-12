# Dashboard Upgrade 13 — Submission Wiring

- Wired Guest Survey and Employee Product Recommendation forms to existing validated models and Supabase service.
- Submissions are OFF by default, gated by `GS_GUEST_ENGAGEMENT_SUBMISSIONS` Dart define.
- Never enable until migrations, RLS, role permissions, and audit/review workflow are verified.
- Shows safe errors; prevents duplicate taps while submitting; avoids displaying sensitive backend errors.
- No Flutter compilation, tests, or live database verification performed.
- Section 01 remains open; project overall historical estimate ~54%, unverified.
