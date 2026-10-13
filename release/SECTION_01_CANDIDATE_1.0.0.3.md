# Section 01 dashboard — 1.0.0.3 staging candidate

Status: staging candidate only. This does not certify Section 01 complete or authorize a production deployment.

## Included in this candidate

- Hide dashboard metrics, customer-count cards, action counts, and insight values when their linked section is not authorized, even if an RPC response contains the field.
- Do not render the signed-in account's raw UUID in dashboard metric details.
- Describe card preferences accurately: they save locally and sync to the signed-in account when the cloud preference service is available.
- Add a regression test for metric visibility with missing data and missing section access.
- Set `release/VERSION` to `1.0.0.3` and add a staging-only workflow that runs source checks, Flutter analysis/tests, builds the web app with that version, and uploads a review artifact.

## Not claimed by this candidate

- No new financial formulas, settlement actions, or authoritative backend contracts are introduced.
- Server-side RLS and API denial are not verified by this UI test.
- The 22 card-to-source mappings, finance policy decisions, iPhone/Windows and accessibility checks, and the full Section 01 acceptance suite remain open.
- No Supabase migration, production workflow dispatch, live deployment, release record, or release notification is performed.

Production publication remains subject to the repository's manual confirmation, backend readiness, staging smoke checks, and protected deployment approval.
