# Tables Upgrade 167 — Independent immutable finance review

Added `gs_table_transfer_finance_reviews`, a separate append-only evidence
table, plus `gs_record_table_transfer_finance_review(request_id)`.

A finance reviewer must have MFA assurance level `aal2`, finance edit and
table-order view permissions, and **must not be the request creator**.
The function locks the request, re-runs existing financial validation, and
records its current result with reviewer, timestamp, amount and blockers.

No approve/execute status is written to the request. All review records
have `outcome='review_only'` and `execution_permitted=false`, enforced
by CHECK constraints; UPDATE/DELETE are rejected by a trigger. The
transfer execution function remains disabled.

This is a *review evidence record*, NOT an authorization to move bills.
Database migration and Flutter runtime tests remain pending.

Tables progress **57% estimated**; **7 completed**, **13 remaining**
of 20 major milestones.
