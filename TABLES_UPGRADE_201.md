# Upgrade 201 — Manager workload limits

- Added configurable maximum active jobs per employee, per responsibility (default 5; range 0–100).
- Database BEFORE trigger serializes concurrent claims/reassignments using an employee-profile row lock, and rejects assignments above the limit.
- Manager-only read/update RPCs; all changes audited.
- Flutter Tables toolbar adds workload-limit management dialog.
- Existing assignments are retained if a manager lowers the limit; new assignments blocked until below cap.
- No push notification or production deployment is claimed.
- Section 02 Tables estimated 80% coded; Flutter/Supabase integration not live-tested.
