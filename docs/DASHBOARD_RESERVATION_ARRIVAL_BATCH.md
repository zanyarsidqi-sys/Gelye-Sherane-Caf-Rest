# Dashboard Reservations and Guest Check-In

Development batch adds two previously unreviewed Dashboard routes.

Reservations reuses the existing table reservation workspace, including its current
search, status filters, creation and cancellation controls. It requires existing
Table Reservations access as well as Dashboard card visibility. Table Reservations
itself retains its existing navigation and workflow.

Guest Check-In reuses CafeTableOverview with initial Reserved filter and an optional
executive theme/title. Existing Arrived and No-show confirmations and server RPCs
are preserved. Users can switch the status filter to Arrived afterward. Requires
Guest Check-In & No-Show permission. Action buttons still depend on server capabilities.

Reservation tiles now format both start/end times explicitly in Baghdad time,
including both dates, instead of relying on the viewer's device timezone.

No new SQL, financial changes or changes to action/booking/cancellation handlers.
Exact inverse substitutions verified the edits preserved all other file content.
The table overview default theme/title remains unchanged outside this Dashboard route.

Five new tests cover real entry routes, missing underlying permissions, executive
presentation, phone RTL, confirmation before arrival, and absent server capability.
Mock RPC tests exercise the existing arrival contract; this batch does not claim
new production mutation tests or completion of the entire reservation lifecycle.
Full analyzer, tests and release-build checks required before publishing.

Current published review coverage: 46/96 improved cards. This draft would raise it
to 48/96 if published, leaving 48 outside the review batches. Counts are improved
cards, not complete workflows. Waiting List needs separate implementation. Standing
Cash billing, discounts, credit settlement, split bills, Dashboard date inheritance,
and remaining cross-section/Phase 4 verification remain pending.
