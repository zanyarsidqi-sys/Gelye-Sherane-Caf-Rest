# Gelye Sherane Cafe

The Flutter web app is deployed to [GitHub Pages](https://cafe.gelyesheranecompany.com/).
Push changes to `main` to build, test, and deploy it through GitHub Actions.

To enable the first deployment, set **Settings > Pages > Build and deployment > Source** to **GitHub Actions** in the repository.

## Cafe website

The app includes a responsive cafe landing page, menu highlights, Supabase
email/password sign-in with authenticator-app MFA, an administrator-only staff
account form, and a reservation form preview. Reservations are not sent or
stored.

After staff authentication, the management UI has 24 sections. Desktop/web uses
a persistent section sidebar; mobile uses Home, Tables, Motel, Menu, Reserve,
and More navigation. Payments and other sections are available from More.
Dashboard and section subcards use the
same responsive card component and grid breakpoints. Every section/card uses
the shared Supabase workspace-record store for authorized, realtime records
with create, edit, status-update, delete, and automatic database audit capture. This
is a flexible record workspace, not a card processor or a substitute for
importing existing cafe transactions; only data actually entered or imported
is shown.

Sections 03–24 surface the reference-design card groups for Payments, Menu,
Kitchen, Motel & Online Orders, Inventory, Staff, Customers, Reservations,
Settings, Notifications, Maintenance, Operations, Statistics, Devices &
Printing, Security & Audit, System Health & Updates, Shisha, Delivery, Marketing,
Customer Feedback, Staff & Operations, and Reports Management.
Existing permission keys are retained when a section is renamed or reordered.
The new Motel & Online Orders, Inventory, Customer, Reservations, Devices &
Printing, Security & Audit, System Health & Updates, Shisha, Delivery, Marketing,
Customer Feedback, Staff & Operations, and Reports Management sections have separate
permission keys, so staff must be explicitly granted access. Legacy cards remain available
under **More cards**; saved records are not removed. Summaries show only
records actually saved for that card, not illustrative figures from references.

The Tables & Orders section includes the 16 reference cards. Dining-table
management uses a dedicated table schema with name/number, area, seat count,
manually maintained status, and draggable floor-map position. Other table,
order, and reservation cards use generic workspace records that can be created,
edited, status-updated, and deleted; table status
does not automatically follow live orders or reservations. Existing generic
table records are not converted into dining tables because their table details
cannot be inferred safely.

Except for dining-table setup and layout, these management cards use the shared
generic record workspace. They do not
implement a payment processor, dedicated product catalog, inventory ledger,
live order pipeline, reservation service, notification delivery system, or
printer/device connection. Device records do not send print jobs, change printer
settings, monitor hardware, update firmware, or open cash drawers. Security cards store generic
records only; they do not manage real accounts, sessions, access policies, IP
restrictions, security alerts, passwords, or MFA settings. System health cards
do not monitor live services or performance, and do not run backups, restore
data, synchronize offline changes, diagnose infrastructure, or install updates.
Shisha cards store menu, order, equipment, stock and service records only; they
do not dispatch orders, decrement inventory, or monitor equipment. Delivery
cards store order, route, vehicle, driver and customer records; they do not
provide GPS/live maps, optimize routes, send driver assignments, process
payments, or dispatch deliveries. Marketing and feedback cards store manually
entered campaign, audience, review, survey and complaint records; they do not
send campaigns, publish external content, collect customer submissions, or
deliver surveys. Staff & Operations cards store directory, attendance, shift,
task, payroll, leave and department records; they do not check staff in or out,
process payroll, or replace the separate Staff Management account and permission
workflow. Report cards store report requests and saved report records; they do
not calculate live business analytics or create/export report files.
Create/edit actions store records for the selected card and do not perform
real-world payment, stock, order, reservation, or notification processing.

## Staff accounts and section permissions

The deployment workflow supplies the Supabase project URL, expected project
reference, and publishable key as Flutter build defines. These are public
client-side values. Never put a Supabase `service_role` key in Flutter or any
other browser code.

The selected project is `lpxuuzfgiggsyhdbsucv`. Its existing
`staff_profiles` table is the authority for the staff role. Never apply
`20261015000000_staff_profiles.sql` to this project: it is a separate,
unapproved candidate intended for a project that does not yet have that table.
The live workspace migrations depend on the existing profile schema and do
not replace Auth triggers or backfill roles.

The permissions migration allows an authenticated user to read only their own
permission rows with a verified AAL2 JWT; clients cannot write these rows
directly. The account-creation function checks the caller's admin role and
AAL2 token, then stores section/card selections using its server-only
service-role key. The live-record migration applies the same MFA and role/card
grants in database policies for every read and write. Record changes are
audited automatically in the database and broadcast through Supabase Realtime.

On first sign-in, the app enrolls an authenticator-app factor and requires a
current six-digit TOTP before showing staff access. Keep the enrollment key
private and save it in an authenticator app. A fixed shared entrance code is
not used: it would be exposed in browser code and would not provide individual
second-factor security. Enable TOTP MFA for the Supabase project.

Create staff access from **Staff Management** in this order:

1. Add a department (for example, Kitchen or Front of House).
2. Create a permission profile for that department and select its sections
   and cards (for example, Kitchen staff).
3. Create a staff account by choosing its department and permission profile.
4. Use the staff directory's edit action to change the department/profile later.

Editing a permission profile updates the grants of all staff assigned to it.
The public-site sign-in dialog does not create accounts, so there is no
permission-less alternate creation path.

Apply these migrations to the selected project's SQL Editor in timestamp order:

```text
supabase/migrations/20261015084000_staff_permissions.sql
supabase/migrations/20261015090000_cafe_workspace_records.sql
supabase/migrations/20261015211000_staff_departments_and_permission_profiles.sql
```

The permissions table must include every management section used by the app,
including Dashboard, Tables & Orders, Payments, Menu, Kitchen, Motel & Online
Orders, Inventory, Staff, Customers, Reservations, Settings, Notifications,
Maintenance, Operations, Statistics, Devices & Printing, Security & Audit,
System Health & Updates, Shisha, Delivery, Marketing, Customer Feedback,
Staff & Operations, and Reports. If you are upgrading a live project that was
created from the older partial permission list, run the expansion migration
after the base migrations:

```text
supabase/migrations/20261016000000_expand_management_section_permissions.sql
```

After the base workspace migrations and permission expansion, apply
`supabase/migrations/20261016010000_cafe_dining_tables.sql` to create the
dedicated dining-table store, row-level security policies, audit capture, and
Realtime publication. Apply
`supabase/migrations/20261016020000_harden_cafe_dining_table_insert.sql` after
it to have the database set table actor IDs and use the same MFA-protected
permission check for inserts. The Add / Edit Tables permission controls table
writes; the Table Overview and map permissions provide read-only access. Apply
both migrations before deploying the UI that uses the floor map.

Do not run the staff-profile review candidate. After the migration succeeds,
deploy the account-creation function to the selected project with the Supabase
CLI:

```powershell
supabase functions deploy create-staff-user --project-ref lpxuuzfgiggsyhdbsucv
```

The function uses Supabase's server-side `SUPABASE_SERVICE_ROLE_KEY` environment
secret. Keep it in Supabase's function environment only; never copy it into the
Flutter app. Create access profiles in **Staff Management** and assign a
profile and department to each new account. The staff workspace opens
automatically after sign-in: Dashboard is always available, while only assigned
sections/cards are shown. Missing or unreadable grants fail closed to Dashboard
only. Administrators see all twenty-four sections.

Each card can store records with a title, details, status, and optional IQD
amount; changes appear live for authorized users. Dashboard and Payments &
Finance summaries use only those saved records and date filters; they do not
invent totals or reconcile against a card-payment processor or cash register.
These generic records do not import old transactions. Disable public sign-ups
in Supabase Auth.

If live records fail to load, the workspace reports the Supabase error and
offers a retry instead of showing placeholder values. Confirm the required
live permissions, workspace-record, and staff-management migrations are
applied in project `lpxuuzfgiggsyhdbsucv`. If the
account lacks an administrator role, review the existing staff profile rather
than granting access through the client. For a `42501` row-level-security
denial, verify the session has AAL2, the account's profile role and section/card
grant, and that the table/schema named in the server error matches the deployed
app. Keep RLS enabled; correct the specific production policy only after
confirming the live schema and policy definitions.

For local development, pass `SUPABASE_URL`, `SUPABASE_EXPECTED_PROJECT_REF`,
and `SUPABASE_PUBLISHABLE_KEY` with `--dart-define` to `flutter run` or
`flutter build web`. Do not commit local credential files.

## Local development

Run `flutter pub get`, then `flutter run -d chrome`. Use `flutter analyze` and
`flutter test` to validate changes.

For Flutter documentation, visit [docs.flutter.dev](https://docs.flutter.dev/).
