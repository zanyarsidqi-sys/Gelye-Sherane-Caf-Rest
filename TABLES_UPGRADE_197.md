# Upgrade 197 — Job-type employee eligibility

Added explicit employee capability grants for take orders, deliver items,
clean, shisha service, tea service, bring bills and other tasks. Employee
management permission is required to grant/revoke capabilities. Changes
are audited. A database trigger blocks assignment to a worker lacking
an active profile or an explicit matching capability, including through
older claim/reassignment RPCs.

**Deployment note:** no automatic grants. Managers must assign relevant
capabilities before workers can claim new jobs. Existing assigned jobs
are not modified retroactively. A capability-management Flutter UI and
eligibility-filtered employee picker are pending.

Estimated Tables completion: **76%**. ZIP verified, but SQL migration,
Flutter build and Supabase end-to-end tests are NOT performed.
