# Upgrade 200 — Eligible employee workload selector

- Manager reassignment form now requires a job number before retrieving candidates.
- Backend lists **only active employees granted the specific job capability**, excluding the current assignee.
- Candidate rows show total active jobs and active jobs of the requested kind, ordered by lighter workload.
- No customer data is exposed by the candidate RPC. Authorization is checked on the server.
- Existing reassignment RPC still performs the authoritative write, trigger eligibility validation, audit and notification actions.
- Reassignment of in-progress delivery remains blocked pending custody handoff.
- ZIP integrity verified. SQL has not been deployed, Flutter has not been compiled, and concurrency has not been tested.
- Section 02 — Tables: **79% estimated**, not verified deployment.
