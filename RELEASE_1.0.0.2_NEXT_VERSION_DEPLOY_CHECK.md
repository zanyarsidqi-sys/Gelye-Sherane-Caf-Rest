# Release 1.0.0.2 — staging version traceability

- Staging workflow now runs when `release/VERSION` changes, even if no Flutter files change.
- Pre-build release metadata checks prevent missing version wiring.
- Build passes the four-part version into Flutter via `APP_RELEASE_VERSION`.
- Each generated web artifact includes `release-version.txt` to compare against the live URL after deployment.
- **No production deployment is performed by these changes.** Before release, confirm Cloudflare routing and actual live version, apply/test Supabase push configuration, and test receipt on subscribed browser and iPhone Home Screen app.
