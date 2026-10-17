# Dashboard order report controls — development batch

Built on published v1.0.7.8. Not a production release.

## Implemented
- Source, status and pricing-mode filters, only when those fields exist in the server report.
- Combined filters and existing search.
- Column sorting with numeric comparison, stable ties, null values last in either direction.
- Clear filters restores search, categorical filters and server ordering without altering dates.
- PDF uses the exact same selected and sorted rows and prints active filters and sort direction.
- Loaded-record scope label; distinct no-data and no-matches messages.
- Card changes reset selections; refresh removes obsolete filter values.

Source contract checked against get_cafe_operational_report columns in
supabase/migrations/20261017030434_cafe_dd_workflows_release.sql.
No database, permissions, payment, order mutation or routing changes.

## Scope
Shared report component already serves 28 Dashboard cards. These are additional
improvements to that group, not 28 newly completed cards. Source/status/mode controls
appear only where returned columns support them; sorting and clear selection apply
to all report layouts. Existing navy/gold style and phone labeled records retained.

Published improvement coverage before this batch: 28 report + 7 cash + 3 expense =
38 of 96 Dashboard card routes. Remaining 58 have not received these review batches.
This does not measure complete workflows.

## Verification
Five new tests cover filter intersection, numeric/stable sorting, null/zero handling,
390px RTL controls, reset on card switch, and reports without categorical columns.
Existing report race/error/malformed-data tests remain required. Full CI analysis,
tests and release web build must pass before release.

## Still pending
Standing Cash unpaid-table billing, credit settlement, cashier discounts, per-item
split bills, dashboard date inheritance hookup and the remaining card workflows.
No reliable overall Phase 3/4 completion percentage is established.
