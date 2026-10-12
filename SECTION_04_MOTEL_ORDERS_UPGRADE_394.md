# Upgrade 394 — Employee Finance Source Mapping

- Adds **Register Source** action to posted finance invoice rows, calling the existing validated Upgrade 393 RPC.
- Adds **View Mapping** read-only dialog with a new permission-checked Supabase RPC.
- No legacy numeric order is created, and no cash, credit, or electronic payment is posted.
- Apply migration `20261010_394_motel_finance_source_mapping_ui.sql` after prior migrations.
- Flutter compilation and live Supabase migrations have not been run in this environment.
- Section 04 estimated progress: 84% (estimate only).
