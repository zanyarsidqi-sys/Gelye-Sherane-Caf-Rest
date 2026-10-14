# Gelye Sherane Cafe

The Flutter web app is deployed to [GitHub Pages](https://cafe.gelyesheranecompany.com/).
Push changes to `main` to build, test, and deploy it through GitHub Actions.

To enable the first deployment, set **Settings > Pages > Build and deployment > Source** to **GitHub Actions** in the repository.

## Cafe website preview

The app includes a responsive cafe landing page, menu highlights, a Supabase
email/password staff sign-in, and a reservation form preview. Reservations are
not sent or stored, and staff management tools are not connected yet.

## Enable staff sign-in

The deployment workflow supplies the Supabase project URL, expected project
reference, and publishable key as Flutter build defines. These are public
client-side values; never put a `service_role` key in a client app.

The app only initializes Supabase when the URL, expected project reference, and
publishable/anon key are all present and match. Until then, the sign-in dialog
explains that setup is missing or invalid. Disable public sign-ups and create
staff accounts in Supabase; the app intentionally has no public sign-up.
Authentication alone does not grant staff permissions: enforce authorization
and row-level security in the backend before adding management data or actions.

For local development, pass `SUPABASE_URL`, `SUPABASE_EXPECTED_PROJECT_REF`,
and `SUPABASE_PUBLISHABLE_KEY` with `--dart-define` to `flutter run` or
`flutter build web`. Do not commit local credential files.

## Local development

Run `flutter pub get`, then `flutter run -d chrome`. Use `flutter analyze` and
`flutter test` to validate changes.

For Flutter documentation, visit [docs.flutter.dev](https://docs.flutter.dev/).
