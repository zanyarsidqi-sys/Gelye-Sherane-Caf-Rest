# Section 01 — Dashboard candidate 1.0.0.5

## Included

- Dashboard card layout preferences synchronize to the signed-in employee's account, with revision checks that surface simultaneous edits instead of overwriting them silently.
- Dashboard metrics, detail entry, action chips, and insight values require the owning section permission.
- Daily cash totals include only order types the signed-in employee can view.
- Adds database migrations 1498 and 1499 for revisioned preferences and permission-scoped cash totals.

## Release checks

- Flutter analysis, unit tests, and web release build pass locally.
- New migrations passed isolated PostgreSQL role and conflict fixtures locally.
- The owner confirmed the Dashboard staging checklist.
- GitHub Actions validation for candidate 1.0.0.5 must pass before production approval.
- Production deployment remains manual through `pages.yml`, which retains its exact version confirmation, backend/staging acknowledgements, and protected environment approval.
