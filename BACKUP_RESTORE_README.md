# Backup & Restore — Phase 3

This module is a non-destructive recovery-readiness checklist, not a backup engine.

- No database write, restore, or export calls are made.
- The application must never assert a successful backup without independent evidence.
- A disaster-recovery test must restore to an isolated Supabase project and validate records and RLS before production use.
- Supabase backup availability and retention vary by plan and configuration; verify them in the project dashboard.
- Checklist selections are in-memory only and reset when the screen is disposed.

Future work: administrator-only backup metadata, immutable audit events, verified restore drill records, and documented retention policy.
