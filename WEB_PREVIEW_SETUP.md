# Real iPhone Safari browser preview — Rest

This is the **actual Flutter source**, not an HTML imitation. The new GitHub Actions workflow compiles `lib/main.dart` into a real Flutter web build. No SDK is needed on an iPhone.

## One-time setup (for the owner/administrator)

1. Create a separate GitHub repository for **Rest** and upload the contents of this ZIP's `gelye_cafe_rest/` directory to the repository root. Never upload production secrets.
2. Create or select a **separate staging Supabase project** for this system. Run approved database migrations in staging and create a test employee with appropriate MFA and permissions. Do not connect staging to production orders or customer data.
3. In GitHub repository Settings → Environments create `staging`. Add the following **environment secrets**:
   - `STAGING_SUPABASE_URL`: `https://<20-letter-project-ref>.supabase.co`
   - `STAGING_SUPABASE_ANON_KEY`: public publishable/anon key (never service_role)
   - `STAGING_SUPABASE_EXPECTED_PROJECT_REF`: the exact 20-letter project ref from the URL
   - For automatic deployment only: `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`
4. Open Actions → **iPhone Flutter Web Staging — Rest** → Run workflow. It creates a deployable `build/web` artifact, even without hosting.
5. To get a Safari URL, create a **separate Cloudflare Pages project** named `gelye-cafe-rest-staging`. Set GitHub environment variable `ENABLE_CLOUDFLARE_DEPLOY=true` and add the Cloudflare secrets. Run workflow again. The deployment step requires a Pages project that already exists and suitable API-token permissions.
6. Restrict staging access at the edge (for example Cloudflare Access) **in addition to** the app's existing employee login/MFA and Supabase RLS. A Pages URL is not private just because it is unadvertised.
7. On iPhone, open the staging HTTPS URL in Safari, sign in with the test employee, and review the real responsive app. Refresh after every successful deployment.

## Safety / limitations

- The Supabase URL, expected project ref, and public/anon key are embedded in the web build; they are **not secrets** once shipped. Supabase RLS, authentication and MFA must provide access control. Never use a service-role key.
- No live web app has been built, deployed or tested in this environment. The workflow is **prepared**, not verified against Flutter compilation or Supabase.
- The app fails closed if the project identity does not match or config is absent.
- The workflow intentionally does not run database migrations automatically or seed production data.
- For web login, review Supabase Auth redirect allow-list, email verification and MFA on the exact staging HTTPS origin.
- Both systems must use independent hosting and staging backend configuration. Do not copy Rest credentials into Sweet.
- The Sweet codebase still requires an audit for legacy Motel Orders/Tourism Mode references; staging should not be treated as production-ready.

## Developer build command (optional)

```bash
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL=https://YOUR_STAGING_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY \
  --dart-define=SUPABASE_EXPECTED_PROJECT_REF=YOUR_STAGING_REF
```

Do not commit credentials or production customer data to the repository.
