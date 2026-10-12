# Tables Upgrade 162 — Financial validation UI

The bill-transfer request review dialog now calls
`gs_validate_table_bill_transfer_request` (introduced in Upgrade 161)
in addition to existing item-level financial preflight. It shows requested
IQD amount, changed items, cash/ledger counts, external payment evidence,
owner offers, overlapping requests and machine-readable blocking reasons.

The dialog remains strictly **read-only**. A clean preliminary result
does NOT allow approval, transfer, or mutation. Backend `execution_permitted`
is false and no Apply button is present.

Tables completion: **47% estimated**; **7 of 20 major milestones completed**,
**13 remain**. Source ZIP integrity checked; no live Flutter compilation or
Supabase execution has been performed.
