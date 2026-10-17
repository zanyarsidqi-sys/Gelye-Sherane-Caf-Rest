# Dashboard table cards — development batch

Six additional Dashboard cards connected to live read-only table snapshots:
Live Tables, Tables Occupied, Available Tables, Table Cleaning, Cleaning Needed,
and Table Service Requests.

Each uses get_cafe_table_overview with its existing server authorization. Dashboard
visibility checks remain unchanged. Staff need eligible Table Overview access in
addition to their assigned Dashboard card; no permission grants or SQL changes.

Features: fixed per-card scope, name/area/customer search, area/mode filters,
clear filters, expandable visit/reservation/service details, Baghdad timestamps,
refresh time, stale-record clearing on failures, retry, late-response protection.
Paid active visits remain occupied. Unknown table states are not available.
Missing guest counts stay Unknown. No money totals are invented. Recorded
availability does not guarantee booking eligibility; upcoming reservations are shown.

Read-only snapshot, manually refreshed. No seating, cleaning completion, payment,
request assignment/completion, QR changes, or new financial workflows implemented.
Operational actions remain in Table Overview. Existing approved executive style reused.

staff_dashboard_page.dart changes are limited to one import, one guarded route,
and read-only entry-card labels. Exact inverse substitution verified each edit
preserved all other content byte-for-byte. Favorites-based navigation is tested
with a seeded saved Tables Occupied favorite.

Seven tests cover scopes, phone RTL, unknown values, stale failures/retry,
late responses, malformed data, all six actual entry-card routes, and unassigned-card
visibility. Full CI analysis/tests/release build required before publication.

Published prior review coverage: 38/96. If published, this batch increases improved
card coverage to 44/96, leaving 52 outside the review batches. These are improved
card routes, not completed workflows. Standing Cash unpaid-table workflow, credit
settlement, cashier discount, individual bill allocation, Dashboard date inheritance,
and remaining cards/integration verification still pending. Overall Phase 3/4
completion cannot be reliably quantified from this batch.
