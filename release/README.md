# Release version source of truth

`release/VERSION` is the candidate version for the next web build. The staging GitHub workflow reads it and passes `APP_RELEASE_VERSION` to Flutter at build time. Both the dashboard footer and shared company footer read `AppReleaseVersion.label`, so they display the version compiled into the deployed web bundle.

Do not change `AppReleaseVersion` fallback (`1.0.0.1`) just to prepare a release: it protects builds made without an explicit release version from falsely claiming a newer version. Production deployment must use the same `--dart-define=APP_RELEASE_VERSION=...` and must verify the live site after deployment. The staging workflow does not deploy to production.

This does not alter any Supabase database records or publish the website.
