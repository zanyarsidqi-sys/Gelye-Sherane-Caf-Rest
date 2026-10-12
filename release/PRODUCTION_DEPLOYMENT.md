# Guarded production web deployment

The Pages workflow is deliberately manual. Merging source to `main` does not deploy it. A deployment requires the candidate version to match `release/VERSION`, an exact typed confirmation, completed backend and staging-check acknowledgements, successful static checks, Flutter analysis/tests, and approval of the protected `github-pages` environment. The workflow refuses a duplicate or lower version than the live `release.json`.

## One-time GitHub setup

1. Merge the reviewed Flutter source and this patch to `main`. The current source must pass the workflow's analyzer and test steps before it can publish.
2. In Repository Settings → Environments, configure `github-pages` to allow deployments from `main` only and require an independent reviewer. Do not allow self-approval.
3. Add these repository variables:
   - `PRODUCTION_SUPABASE_URL`: exact production URL, `https://<project-ref>.supabase.co`
   - `PRODUCTION_SUPABASE_EXPECTED_PROJECT_REF`: the same lowercase 20-character project ref
   - `PRODUCTION_WEB_PUSH_PUBLIC_KEY`: public VAPID key for the production push service
4. Add `PRODUCTION_SUPABASE_ANON_KEY` as a repository secret. It is a publishable client key; never use a service-role key in this workflow.
5. Set GitHub Pages to use GitHub Actions. Keep VAPID private material, dispatcher secrets, and database credentials in their respective Supabase secret stores; this workflow does not handle or deploy them.

## Release procedure

1. Complete and independently verify the production Supabase migrations, Edge Function, VAPID configuration, scheduled dispatcher, and staging browser/device smoke tests. This workflow does not apply database changes or configure those services.
2. On `main`, open Actions → **Deploy Gelye Sherane production** → Run workflow. Enter the exact value from `release/VERSION`, type `DEPLOY <version> TO PRODUCTION`, and confirm backend readiness and staging smoke tests.
3. The build job runs with read-only repository permission and uploads a checksummed artifact. After it passes, a reviewer approves the protected `github-pages` deployment job. That job only downloads and publishes the verified artifact, then checks the live manifest, version marker, and JavaScript bundle hash.
4. After live verification and owner review, publish the stable web release record separately in the app's release panel. This database action is intentionally not automated here because it can send release notifications.

The workflow does not automatically create a GitHub Release, publish a Supabase release record, send push notifications, or roll back production. The source currently needs to pass `flutter analyze` and `flutter test` before deployment can proceed.
