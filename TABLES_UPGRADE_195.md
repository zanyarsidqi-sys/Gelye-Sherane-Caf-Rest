# Tables Upgrade 195 — Searchable Active Employee Picker

Replaced the manual employee UUID input in Manager Job Reassignment with
an employee directory search and selection list. The directory uses the
existing permission-checked `gs_service_assignable_employees` RPC and
only returns active employee profiles. The selected account ID is passed
to the existing atomic, audited reassignment RPC from Upgrade 194.

The interface displays directory-loading errors and disables reassignment
until a worker is selected. The backend remains responsible for enforcing
manager permissions and blocking unsafe in-progress delivery handovers.

**Limitations:** The employee directory RPC originates in the existing
migration 042 and must be applied in the correct order. That earlier RPC
uses `employee_profiles` and its `is_active`/`full_name` columns; verify
against the deployed schema. The 194 reassignment RPC checks the auth
account but does not itself re-check employee profile active status, so
other callers could supply an inactive employee UUID. Harden backend
eligibility before production deployment. No live Flutter build or
Supabase test performed.

Tables completion ~74% estimated. ZIP integrity verified.
