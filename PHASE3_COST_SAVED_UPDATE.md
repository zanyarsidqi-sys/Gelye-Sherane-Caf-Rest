# Phase 3: Monthly cost estimates saved locally

- Cost Management now supports switching between calendar months.
- Estimates are stored using shared_preferences, scoped by Supabase user ID and year/month.
- Switching months prompts before discarding unsaved edits.
- Saving and loading errors display snackbars; no Supabase schema or accounting entries are changed.
- This is not an expense ledger, cloud sync, or revenue reconciliation.
- Test tomorrow: flutter pub get, flutter analyze, flutter run -d chrome; save an estimate, restart, switch months, verify employee separation and permissions.
