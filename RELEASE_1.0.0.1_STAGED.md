# Release 1.0.0.1 — published

The user approved publication by saying Done. Build and database blockers were resolved on 12 October 2026.

## Implemented
Release drafts, platform/channel filters, review controls, audit history, idempotent mutations, optimistic revisions, previous-release catalog restoration, and foreground update notices across all 35 sections. Public version 1.0.0.1; duplicate section footer removed. Existing navigation, permissions and saved-session mechanism retained.

## Verified
- Flutter 3.47.7 / Dart 3.13.5; dependency lockfile enforced.
- 70 Flutter tests passed, including release-version comparison and draft validation.
- Production JavaScript web build succeeded; generated JavaScript syntax checks passed.
- 35 isolated PostgreSQL-compatible database checks passed, including anonymous default-grant rejection.
- Applied app_release_management_1493 and app_release_revoke_anonymous_execution to the intended Supabase project.
- Both new tables have RLS. Anonymous release RPC execution and authenticated direct INSERT are denied. No-session authorization returns false.
- Exact row-content fingerprints of employee_profiles, employee_section_permissions, management_sections and employees were identical before and after migration.

## Data preservation
The migration adds release metadata and functions only. No pre-existing business, employee, permission or authentication records were changed or deleted. Notifications do not reload, clear storage or log out the active user. Catalog rollback does not restore a database or deploy a binary.

The screenshot showed the latest scheduled backup at 2026-10-11 17:43:40 UTC. It does not establish recovery of later changes or Storage objects. No restore rehearsal was performed. This package is a source checkpoint, not a live database backup.

## Remaining validation limits
Signed-in iPhone and Windows end-to-end smoke testing is not performed. Native installers are not built. The compiler reports existing secure-storage WebAssembly incompatibility; the published build uses JavaScript. Existing Cupertino font warning remains.

GitHub deployment succeeded: https://github.com/zanyarsidqi-sys/Gelye-Sherane-Caf-Rest/actions/runs/38276398492
GitHub release: https://github.com/zanyarsidqi-sys/Gelye-Sherane-Caf-Rest/releases/tag/1.0.0.1
Live site: https://cafe.gelyesheranecompany.com/
Commit: 73062d999546f93a44c80d05467e4451cc15159a
The live release.json reports 1.0.0.1. No release catalog entry should falsely assert that device smoke tests or restore rehearsal passed. Release review remains separate from verified hosting deployment.

Archive SHA-256: d43f13fc0471f3ee0652df05e2e6e5c7bb397da4ab320bd7401228dc0bb7fe5d
