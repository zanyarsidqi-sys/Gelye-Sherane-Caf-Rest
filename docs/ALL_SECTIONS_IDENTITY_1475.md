# Upgrade 1475 — both projects, all 35 sections + independent mapping review

## Shared all-section improvement
The existing SectionShell now rechecks active employee permissions on app foreground resume and on all authentication changes (including token refresh / MFA changes), not only changes in employee user ID. It also guards against a stale section ID after asynchronous permission lookup. Applies to all 35 sections using SectionShell; no route, filter, footer or existing section content removed.

## Finance addition
`gs_approve_motel_cafe_identity` records second-person review of an explicit invoice-to-order mapping; registrant cannot approve own mapping. One immutable approval per mapping; repeat requests return existing evidence. Reviewer must inspect real invoice/order documents before approving; database cannot independently prove evidence authenticity. This does NOT settle an invoice, connect unified ledger, or certify any IQD totals.

## Staging procedure
Apply existing migrations first, then this migration; run diagnostics with `psql -v ON_ERROR_STOP=1 -f ...` against authorized staging. Test two distinct authenticated users, denial of self-approval, conflicting repeat approval, RLS direct read denial, and transaction rollback. Not executed by offline packaging. No provider credentials are bundled.

## Rollback
Keep old ZIP. Do not delete financial evidence in production. To revert UI, restore prior section_shell.dart. To retire approval RPC revoke execute; retain immutable evidence for audit.
