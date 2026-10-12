# Tables Upgrade 196 — Assignment Eligibility Enforcement

Hardened **both** job claiming and manager reassignment at the Supabase
RPC layer. Claiming requires an active employee profile; reassignment
rejects inactive/missing employee profiles even if a caller bypasses the
Flutter searchable employee picker. Uses a central locked-down
`gs_is_active_table_worker` helper against `employee_profiles.is_active`.

Preserves row locking, job status constraints, audit events, notification
events and the ban on reassignment of in-progress deliveries.

**Remaining:** Eligibility does not yet validate per-job departmental
qualifications or target employee's effective permissions; that requires
a dedicated user-target permission function. Notification push, partial
quantities, money reconciliation, compilation and live Supabase testing
remain pending. The migration requires the `employee_profiles` schema
and prior migration sequence to be present.

Tables estimated **75%** coding completeness, not production readiness.
ZIP integrity checked.
