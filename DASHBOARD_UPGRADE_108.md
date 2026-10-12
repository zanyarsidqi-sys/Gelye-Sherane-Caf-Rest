# Upgrade 108 — Physical departure and service tasks work together

**Actual implemented source:** `gs_record_visit_guest_departure` records physical
customer departure for a specific active table visit and creates visit-linked
cleaning and optional staff-confirmed shisha pickup tasks. The function is
transactional and idempotent for repeated calls. Upgrade 107's task completion
function is updated so tasks can be completed after physical departure even
when the visit remains `active` awaiting financial settlement. This resolves
the prior unreachable cleaning-stage prerequisite.

**Financial safety:** The table stays occupied, the visit stays active, and
no bill, payment, refund, or settlement is changed. Physical cleaning may be
completed before financial reconciliation, but the table **cannot be released**.
Existing checkout/release gates remain fail-closed.

**Still required:** Flutter action UI for recording departure and completing
tasks, payment settlement verification, and final release after all checks.
The ZIP was integrity checked; no Flutter compile or Supabase runtime test.
