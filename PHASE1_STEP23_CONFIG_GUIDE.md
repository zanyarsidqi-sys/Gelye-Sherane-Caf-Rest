# Phase 1 Step 23 — Supabase build configuration isolation (Rest)

The app now **refuses to initialize** unless `SUPABASE_URL` uses HTTPS and its host exactly matches `SUPABASE_EXPECTED_PROJECT_REF + .supabase.co`. It also requires a nonempty public key. This is a build-time identity check, **not** a substitute for server-side RLS or permission checks.

Example build inputs (replace placeholders; use a different ref for each application):

`flutter build web --dart-define=SUPABASE_URL=https://<your-20-letter-ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable-key> --dart-define=SUPABASE_EXPECTED_PROJECT_REF=<your-20-letter-ref>`

Do not pass a service-role or secret key into Flutter. Keep real credentials outside source control. Verify the actual project refs and histories using Step 22; they were not available in this environment. Public keys and refs alone cannot guarantee the two deployed builds are independent.

Run: `python tools/phase1_step23_config_guard.py`.
