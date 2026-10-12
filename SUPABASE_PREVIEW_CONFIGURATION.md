# Supabase preview configuration — 2026-10-12

The user supplied the project URL and publishable key. Flutter main.dart reads
SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_EXPECTED_PROJECT_REF, not NEXT_PUBLIC_*.
The existing main.dart uses SUPABASE_ANON_KEY as the Supabase publishableKey argument.

From this Flutter project directory run:

    flutter build web --release --dart-define-from-file=config/supabase.public.json

For local Chrome development:

    flutter run -d chrome --dart-define-from-file=config/supabase.public.json

This file contains only public client configuration. Never add service-role keys.
No authentication, MFA, permission checks, or backend policies were changed.

The hosted Upgrade 1492 compiled JavaScript was updated with five exact configuration
literal substitutions because the Flutter SDK is unavailable in this session.
Its main JavaScript filename is content-versioned to avoid loading the old configuration.
This is not a fresh Flutter build. End-to-end login, backend migrations, and payments
have not been verified. Previously recorded test results were not rerun in this session.
