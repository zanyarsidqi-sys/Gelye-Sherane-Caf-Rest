# Phase 3 — Section layout update

- Replaced static workflow card grids in `lib/shared/section_shell.dart` with compact, numbered iPhone-friendly list rows.
- Added clear **planned / not enabled** labels so previews cannot be mistaken for functional actions.
- Retained workflow search and employee permission gating.
- Wrapped the section preview in `Material` to support text input correctly.
- No Supabase migrations, order pricing, MFA, or permission service changes.
- Flutter compilation and Windows integration testing deferred to tomorrow.
