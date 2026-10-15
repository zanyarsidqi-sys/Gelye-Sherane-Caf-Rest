# Gelye Sherane Cafe

The Flutter web app is deployed to [GitHub Pages](https://cafe.gelyesheranecompany.com/).
Push changes to `main` to build, test, and deploy it through GitHub Actions.

To enable the first deployment, set **Settings > Pages > Build and deployment > Source** to **GitHub Actions** in the repository.

## Cafe website

The app includes a responsive cafe landing page, menu highlights, Supabase
email/password sign-in with authenticator-app MFA, an administrator-only staff
account form, and a reservation form preview. Reservations are not sent or
stored.

## Configure staff administration

The deployment workflow supplies the Supabase project URL, expected project
reference, and publishable key as Flutter build defines. These are public
client-side values. Never put a Supabase `service_role` key in Flutter or any
other browser code.

The first administrator can be an existing Supabase Auth user. In the Supabase
SQL Editor, run `supabase/migrations/20261015000000_staff_profiles.sql`, replace
`REPLACE_WITH_YOUR_SUPABASE_EMAIL` in `supabase/BOOTSTRAP_ADMIN.sql` with that
user's email, and run the bootstrap SQL once. This one-time step grants that
existing account the admin role; signing in by itself does not grant admin
access. The migration backfills users whose trusted Auth app metadata already
contains an `admin` or `staff` role and provisions future profiles only for
those server-assigned roles. It does not grant staff access to ordinary public
sign-ups.

On first sign-in, the app enrolls an authenticator-app factor and requires a
current six-digit TOTP before showing staff access. Keep the enrollment key
private and save it in an authenticator app. A fixed shared entrance code is
not used: it would be exposed in browser code and would not provide individual
second-factor security. Enable TOTP MFA for the Supabase project.

Deploy the account-creation function with the Supabase CLI, linked to the same
project:

```powershell
supabase functions deploy create-staff-user --project-ref axiyxffuagraoydvzicr
```

The function uses Supabase's server-side `SUPABASE_SERVICE_ROLE_KEY` environment
secret. Keep it in Supabase's function environment only; never copy it into the
Flutter app. After the database migration and function are deployed, sign in
with the administrator account and choose **Add staff user**. New accounts are
created with the staff role, and only an administrator can create them. Disable
public sign-ups in Supabase Auth.

If sign-in succeeds but the app says it cannot load staff permissions, apply
the database migration. If it says the account has no administrator role, run
the one-time bootstrap SQL using the email of the existing Supabase Auth user.

For local development, pass `SUPABASE_URL`, `SUPABASE_EXPECTED_PROJECT_REF`,
and `SUPABASE_PUBLISHABLE_KEY` with `--dart-define` to `flutter run` or
`flutter build web`. Do not commit local credential files.

## Local development

Run `flutter pub get`, then `flutter run -d chrome`. Use `flutter analyze` and
`flutter test` to validate changes.

For Flutter documentation, visit [docs.flutter.dev](https://docs.flutter.dev/).
