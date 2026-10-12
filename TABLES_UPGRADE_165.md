# Tables Upgrade 165 — Approval preparation without financial mutation

New `gs_prepare_table_bill_transfer_approval(request_id)` RPC returns a
permission-checked, read-only finance-review summary: request amount,
blocking reasons, readiness for further review, reviewer identity and
review timestamp. `execution_permitted` is **always false**. No approval,
financial allocation, guest move, payment posting, or bill transfer occurs.

Staging-only metadata test added. Database execution and Flutter
compilation have not been performed. The prior source and ZIP are retained.

Tables development: **53% estimated**, **7/20 major milestones complete**,
**13 remaining**. Next: connect approval-preparation summary to the
Flutter review panel; later build independent authorization and atomic
financial transfer with proper transaction tests.
