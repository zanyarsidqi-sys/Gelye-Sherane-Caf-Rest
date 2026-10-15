# Gelye Sherane Cafe

The Flutter web app is deployed to [GitHub Pages](https://cafe.gelyesheranecompany.com/).
Push changes to `main` to build, test, and deploy it through GitHub Actions.

To enable the first deployment, set **Settings > Pages > Build and deployment > Source** to **GitHub Actions** in the repository.

## Cafe website

The app includes a responsive cafe landing page, menu highlights, Supabase
email/password sign-in with authenticator-app MFA, an administrator-only staff
account form, and a reservation form preview. Reservations are not sent or
stored.

After staff authentication, the management UI follows the approved 11-section
layout. Desktop/web uses a persistent section sidebar; mobile uses Home, Tables,
Kitchen, Payments, and More navigation. The section and subcard screens are
currently UI previews: this Supabase project does not yet have the operational
business tables and secure services for live values or management actions.
The UI labels these areas as not connected and does not display fabricated
operational data.

## Staff accounts and section permissions

The deployment workflow supplies the Supabase project URL, expected project
reference, and publishable key as Flutter build defines. These are public
client-side values. Never put a Supabase `service_role` key in Flutter or any
other browser code.

Do not apply the review-candidate SQL or deploy the Edge Function to the live
project yet. Verify the schema, existing auth trigger, MFA lifecycle, and
service-role writers in an isolated staging project first. In particular,
`20261015000000_staff_profiles.sql` is an unapproved review candidate, and
`20261015084000_staff_permissions.sql` depends on its `staff_profiles` table.
The candidate intentionally does not backfill trusted app metadata or replace
the existing auth trigger.

In staging, create the initial administrator only through the separately
reviewed bootstrap procedure. Signing in alone never grants administrator
access. The permission migration allows an authenticated user to read only
their own permission rows with a verified AAL2 JWT; clients cannot write these
rows directly. The account-creation function checks the caller's admin role
and AAL2 token, then stores the section/card selections using its server-only
service-role key.

On first sign-in, the app enrolls an authenticator-app factor and requires a
current six-digit TOTP before showing staff access. Keep the enrollment key
private and save it in an authenticator app. A fixed shared entrance code is
not used: it would be exposed in browser code and would not provide individual
second-factor security. Enable TOTP MFA for the Supabase project.

After the staging schema and compatibility checks pass, deploy the
account-creation function to that staging project with the Supabase CLI:

```powershell
supabase functions deploy create-staff-user --project-ref STAGING_PROJECT_REF
```

The function uses Supabase's server-side `SUPABASE_SERVICE_ROLE_KEY` environment
secret. Keep it in Supabase's function environment only; never copy it into the
Flutter app. In the administrator's **Add staff user** form, select full
sections or individual cards when creating the account. The staff workspace
opens automatically after sign-in: Dashboard is always available, while only
assigned sections/cards are shown. Missing or unreadable grants fail closed to
Dashboard only. Administrators see all eleven sections.

These grants currently govern navigation only. Operational data tables and
their server-side authorization policies are not implemented, so the section
screens remain previews and must not be treated as protected live business
operations. Do not deploy the migrations or function to production until
staging behavior is verified and production deployment is explicitly approved.
Disable public sign-ups in Supabase Auth.

If staff permission loading fails, the app opens Dashboard only and reports the
error; confirm that the reviewed permissions migration is installed in the
matching staging project. If the account lacks an administrator role, review
the staging bootstrap configuration rather than granting access through the
client.

For local development, pass `SUPABASE_URL`, `SUPABASE_EXPECTED_PROJECT_REF`,
and `SUPABASE_PUBLISHABLE_KEY` with `--dart-define` to `flutter run` or
`flutter build web`. Do not commit local credential files.

## Local development

Run `flutter pub get`, then `flutter run -d chrome`. Use `flutter analyze` and
`flutter test` to validate changes.

For Flutter documentation, visit [docs.flutter.dev](https://docs.flutter.dev/).
