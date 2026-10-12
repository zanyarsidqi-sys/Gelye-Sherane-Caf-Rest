# Upgrade 497 — Dashboard coordinated refresh

## Actual change

- Dashboard pull-to-refresh now waits for all four independent sources: operational summary, seven-day order activity, daily cash collections and seven-day cash collections.
- Each source retains its own FutureBuilder error display; failure of one source does not hide successfully loaded others.
- Refresh button and app-resume refresh use the same loading logic.

## Scope and verification

This is a Flutter source-level change, not a database migration. Existing database authorization, cash separation, and financial safeguards remain unchanged. Flutter analyze/build and live Supabase tests have not been run. Dashboard coding progress remains a provisional 84%; accounting integration and end-to-end tests are outstanding.
