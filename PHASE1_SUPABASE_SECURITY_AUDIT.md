# Phase 1 — Step 4: Supabase configuration and security audit

Application: Gelye Sherane Cafê & Rest
Audit status: STATIC INSPECTION ONLY — not a live Supabase security test.

## Verified from project files
- Flutter startup uses compile-time SUPABASE_URL and SUPABASE_ANON_KEY via String.fromEnvironment.
- Startup displays an error if either configuration is absent.
- Supabase migration SQL files found: 475.
- CREATE POLICY occurrences in migrations: 13; auth.uid()/auth.jwt() occurrences: 1134. Counts do NOT establish that RLS is correctly enabled or policies are safe.
- No Supabase credentials or production project IDs were supplied or validated.

## Required before Phase 1 signoff
1. Provision two distinct Supabase projects and document their project references privately; never commit service_role keys.
2. Supply separate SUPABASE_URL and public publishable/anon key at build time for each application.
3. Review migration dependency order and identify drafts versus deployable migrations. Do not deploy all SQL blindly.
4. Confirm RLS is enabled on every client-accessible table; test cross-user and cross-café access denial with real authenticated sessions.
5. Verify staff MFA (AAL2), permissions, and Edge Function authorization using non-admin clients.
6. Configure separate backup/restore, secrets, storage buckets, and incident audit policies.
7. Run actual Flutter compilation and live Supabase integration tests; currently NOT RUN.
8. For Sweet, remove/segregate legacy Motel Orders and Tourism Mode dependencies before deployment.

## Local check
Run `python3 tools/check_phase1_config.py` inside the extracted project. This only checks source configuration and cannot validate the remote database.

## Security note
Supabase publishable/anon keys are client-visible by design; authorization must be enforced through RLS and trusted server functions. Never embed service_role or secret keys in Flutter.

Sources: project lib/main.dart, pubspec.yaml, supabase/migrations; Supabase documentation https://supabase.com/docs/guides/database/postgres/row-level-security and https://supabase.com/docs/guides/api/api-keys
