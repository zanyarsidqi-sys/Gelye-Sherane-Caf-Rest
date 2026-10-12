# Phase 1 Step 8 — Rest

Added a reproducible SHA-256 inventory of 475 migration files and a read-only integrity gate.

Run `python tools/phase1_step8_migration_gate.py` from the project root. Exit 3 means collision groups block deployment. Do not rename or apply migrations without reconciling the deployed migration history.

This is static validation only; database execution, RLS/MFA, and Flutter builds remain unverified.
