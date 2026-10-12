# Upgrade 1455 — durable credit charge source linkage

This upgrade links **new** verified credit journal charges to their motel invoice in the **same database transaction** using an AFTER INSERT trigger. It does not settle an invoice, allocate prepaid funds, link a numeric cafe order, or certify Dashboard totals.

## Added
- `gs_financial_credit_invoice_charge_links` with unique invoice, request, journal keys, positive IQD, restrictive RLS, immutable record state.
- Source-validated `gs_financial_link_credit_charge_to_invoice` trigger. A mismatch raises an error, rolling back the journal insertion and the surrounding account balance update.
- Immutable-link update/delete trigger.
- Diagnostic for historical unlinked or inconsistent credit journal charges.
- 20 executable source assertions.

## Staging release gate (NOT RUN)
1. Apply migrations in sequence to a **clone**; inspect existing credit journal charge records before enabling any new posting.
2. Verify `gs_financial_credit_invoice_charge_links` is initially empty on a clean clone; audit historical charges using the diagnostic, **never silently backfill**.
3. Run a permitted verified credit charge and confirm one journal entry, one invoice link, one account balance change, and an invoice still `unpaid`.
4. Retry with identical key: no new journal or link; retry with changed key: rejected.
5. Run two concurrent charges for the same invoice and for the same account; at most one succeeds; confirm exact rollback for failures.
6. Test wrong invoice amount, cancelled request, stale barcode, inactive account, cash collision, wrong registry, credit limit and missing permission; all must leave balance, journal and link unchanged.
7. Verify direct authenticated writes to link table fail and update/delete is rejected even with privileged table access.
8. Check triggers and journal guards from upgrades 1445–1453 coexist and no lock-order deadlocks occur.
9. Test historical credit journal entries separately; no fabricated linkage or paid status.
10. Test Flutter compilation and full payment workflows; **do not** enable production settlement until signed off.

## Known blocker
The original motel invoice payment-status constraint permits `unpaid` (and `paid_cash` where existing cash functions support it), not certified credit/prepaid settlement. This migration deliberately does not change it.
