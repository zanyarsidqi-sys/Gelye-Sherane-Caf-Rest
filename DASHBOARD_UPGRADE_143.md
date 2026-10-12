# Upgrade 143 — Offline migration dependency audit

Scanned **127** bundled SQL migrations for referenced table names without a corresponding CREATE TABLE definition.

This is a static source audit only; it cannot prove that the live Supabase schema has matching tables, columns, triggers, or RLS.

No flagged references among the selected finance tables.

A reproducible scanner is included at `tools/audit_migration_dependencies.py`. Its warnings are blockers for review, not automatic permission to alter production schema. Mixed checkout stays disabled.
