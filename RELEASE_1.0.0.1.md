# Release 1.0.0.1

Gelye Sherane Café & Rest — https://cafe.gelyesheranecompany.com/

- Adds release drafts, review controls, release history and permission-protected release management.
- Adds foreground update notices across all 35 management sections. Notices do not force reload, clear storage or sign users out.
- Displays the public release version 1.0.0.1 and removes the duplicated section footer.
- Adds release database tables with MFA checks, row-level security and an audit history.

Validation: 70 Flutter tests and 35 isolated database checks passed. Flutter 3.47.7 production JavaScript web build succeeded. Live release-table access checks passed; checksums of all four pre-existing public tables remained unchanged after the additive migration.

Limitations: a signed-in iPhone/Windows end-to-end smoke test and backup restoration rehearsal have not been performed. Update notices require the new client; older open pages must be reopened after saving work. This is a web release, not an iOS/Android/Windows installer. Release-catalog review controls do not deploy hosting binaries.

Package SHA-256: d43f13fc0471f3ee0652df05e2e6e5c7bb397da4ab320bd7401228dc0bb7fe5d
