# Release 1.0.0.2 — Staging source-transfer audit

This is a staging-only audit marker, **not** the Flutter source and **not** proof of a successful build.

- Source archive: `Gelye_Cafe_Rest_1.0.0.2_Archive_Integrity_Staging.zip`
- SHA-256: `f95e611c88869dcd49759d9ab8ca40c69fae0d8ea57ac4e2c2473bf8bc26c638`
- ZIP entries: 2,675; ZIP CRC: passed
- Dart management section files: 35
- Preliminary regex scan for private keys, GitHub tokens, AWS keys and Supabase service-role assignments: zero matches (not a comprehensive secrets audit)
- Source `pubspec.yaml` currently declares `version: 1.0.0+29`; reconcile release version before publishing.
- GitHub Actions run 38303702479 failed at the source-presence check. No Flutter build or artifact was produced.
- The complete source archive has **not** been committed to this GitHub branch.
- Production branch and production deployment must remain unchanged.
