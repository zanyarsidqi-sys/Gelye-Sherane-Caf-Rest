# Dashboard two-batch completion plan

User approved two batches of 23 remaining cards and requested publication after completion. Existing production: v1.0.11.12, 52 of 98 cards with published improvements. This does not mean 52 workflows are complete.

## Batch 1 — 23 cards

1. Table Reservations — Tables & Reservations
2. Waiting List — Tables & Reservations
3. Table Map — Tables & Reservations
4. Minibar Live Board — Kitchen & Minibar
5. Station Printers — Kitchen & Minibar
6. Low Stock — Kitchen & Minibar
7. Nargile Orders — Kitchen & Minibar
8. Customer Feedback — Orders & Customer Service
9. Service Speed — Orders & Customer Service
10. Takeaway & Delivery — Orders & Customer Service
11. Feedback — Orders & Customer Service
12. Employee Attendance — Employees & Operations
13. Employee Assignments — Employees & Operations
14. Pending Staff Tasks — Employees & Operations
15. Maintenance Requests — Employees & Operations
16. Notifications & Alerts — Employees & Operations
17. Customers — Employees & Operations
18. Employees — Employees & Operations
19. Tasks — Employees & Operations
20. Events — Employees & Operations
21. Maintenance — Employees & Operations
22. Attendance — Employees & Operations
23. Tourism Customers — Employees & Operations

## Batch 2 — 23 cards

1. Invoices — Payments & Finance
2. Discounts — Payments & Finance
3. Credit Accounts — Payments & Finance
4. Confirm Credit — Payments & Finance
5. Accounts Receivable — Payments & Finance
6. Credit Collections — Payments & Finance
7. Credit Approval History — Payments & Finance
8. Cash Transfers — Payments & Finance
9. Staff Performance — Employees & Operations
10. Inventory Overview — Inventory & Purchasing
11. Low Stock Alerts — Inventory & Purchasing
12. Purchase Requests — Inventory & Purchasing
13. Pending Approvals — Inventory & Purchasing
14. Supplier Deliveries — Inventory & Purchasing
15. Inventory Waste — Inventory & Purchasing
16. System Health — Reports & System
17. Backup & Sync Status — Reports & System
18. Dashboard Personalization — Reports & System
19. Reports — Reports & System
20. Security — Reports & System
21. Backup — Reports & System
22. Offline Mode — Reports & System
23. Personalization — Reports & System

## Restored-access checkpoint

Automatic approval review previously failed due to a reported usage limit. After the user reported restored access, the same update tool succeeded. No bypass was used.

Initial Batch 1 implementation: Waiting List and read-only Dashboard Table Map.
- Waiting List is connected both from Dashboard and the Tables section Reservation Waiting List.
- Existing server RPCs preserve authorization, version conflicts, command identity, table availability checks and seating permission.
- Add party, offer, accept, arrive, seat, return to queue and retain cancelled/seated history.
- Oldest first, search, active/history, refresh, stale-data clearing.
- Ambiguous command retries retain the same request ID during the mounted screen session; no durable cross-device retry queue is claimed.
- Dashboard Table Map reuses the saved layout, permission gate and area/status/search filters. Editing stays in the existing table-management workflow.
- No database changes and no production data mutations performed during tests.
- Seven new tests cover transition choices, validation, ambiguous retry identity, confirmation, history, capabilities, failed refresh, offers, mobile RTL and navigation.
- Analysis and full tests passed at code head 1a208970dcd7f681ddb0edc44485116a19f8f609. Release build status is recorded in PR23.
- These are 2 of the 23 planned card improvements, not completion of Batch 1.

## Completion gates

Each card must have its actual data source, required authorized actions, loading/error/empty states, matching Style 2 layout and relevant tests. A design preview or a renamed generic notes workspace does not establish a completed domain workflow. Reusing an existing workflow must preserve its underlying permissions.

Before publishing either batch, record each card's implemented behavior and remaining limitations. Financial settlement, Standing Cash semantics, credit accounting, server-enforced read-only/time-range restrictions, historical itemized bills and translations remain independent unfinished work within previously improved cards. Do not convert the 98-card improvement count into a claim of total functional completion.

## Expanded checkpoint — 17 October 2026

Latest instruction: improve all remaining cards, then publish once. The two lists above organize development, not separate releases. Keep PR23 unpublished.

Nine additional unique Dashboard card routes now have improvements:
- Table Reservations: Today/Upcoming/Past/All dates filters, Baghdad-day overlap handling and matching counts. Shared Reservations route benefits too but is not double-counted.
- Station Printers: existing printer workflow behind underlying station permissions, executive styling, stale ticket removal and disabled actions after load failures.
- Service Speed: receipt-to-first-ready timing, measured coverage, mean and median; cancelled and missing/invalid samples excluded. No fabricated response/delivery timing.
- Takeaway & Delivery: permission-scoped online/walk-in tracking and safe permission changes. Pickup versus delivery, driver assignment and fulfilment-specific milestones remain pending.
- Tourism Customers: current active visits in Tourism pricing mode with guest totals and incomplete-count warnings; not tour-company history.
- Employees: searchable minimal staff directory using authorized table-assignment data. Full HR profiles and payroll are not added.
- Employee Assignments: existing table-assignment operations with current occupied visits and backend capability checks.
- Maintenance and Maintenance Requests: shared table-repair lifecycle, required table/problem, server version and request identity, admin review, retained history. Other asset maintenance, evidence upload and employee assignment in this UI remain pending.

Shared order refreshes now clear stale data and reject outdated responses.

Verified code head: c5a1d415c0d8985caa2c54fd2e31f672cbfbfc60.
GitHub run 39038641270 passed analysis, full Flutter tests and release web build.
Tests include timing coverage, reservation boundaries, tourism scope, source permission changes, stale clearing, directory search, repair approvals, form validation and Dashboard permission gates. No production mutation tests or authenticated device end-to-end checks were performed.

Progress by unique card improvements: 52 published + 11 unpublished = 63 of 98; 35 cards remain outside these improvement batches. Batch 1 has 11 of 23 improved, with 12 outstanding; Batch 2 has 23 outstanding. This is not a functional-completion percentage. Full financial settlement, credit accounting, time/read-only permission enforcement and other prior gaps remain on the checklist.

## Task and report checkpoint — 17 October 2026

Latest instruction remains one combined publication after the remaining work. No deployment or production database changes in this checkpoint.

Three additional unique routes implemented in draft:
- Tasks: permission-scoped table-service task board combining maintenance, chair requests, waiting-list parties and table groups. Oldest first, source/search/history/assignment filters; exact returned table and employee information; source failures explicitly mark incomplete results.
- Pending Staff Tasks: the same underlying task board, restricted to non-terminal records. This is table-service work, not a new general staff task or shift system.
- Reports: searchable library of existing authorized Dashboard reports. Opening a report preserves its existing server permission, date selection, filters and export behavior. Losing report permission removes the selected report.

Administrators can assign a task to an employee using the repository's versioned, audited task command. Confirmation, stale-version handling and identical-request retries are included. Retry identity lasts for the mounted screen only. Staff cannot see assignment actions without the server capability, and the server still enforces authorization. Status changes remain in the original workflow; no new general task creation, deadlines, notifications or attendance ledger is claimed.

### Corrected backend assumption — release blocker
A read-only production catalog check found that public.cafe_table_tasks and both get_cafe_table_task_workspace / perform_cafe_table_task_command are absent. Earlier descriptions of these as "existing" referred to repository code, not deployed database availability. Waiting List, Maintenance, Maintenance Requests, Tasks and Pending Staff Tasks require the table-task migration before they can work against production.

The existing undeployed migration 20261017092728_cafe_table_card_workflows.sql used double quotes for string replacements inside its patch block. Corrected to dollar-quoted string literals, with explicit failure if either expected function patch target is absent. Read-only checks confirm both patch targets currently match the deployed table_access/table_overview definitions.

CI now executes the actual task migration in an isolated PostgreSQL 17 database and checks create/assignment retry identity, record versions, maintenance lifecycle, staff denial, maintenance seating guard, audit entries and direct/anonymous access restrictions. Auth/MFA, chair movement and seating functions are fixture boundaries; this is not full Supabase end-to-end acceptance or a production migration rehearsal. Existing Flutter tests use mocked RPC responses.

Release gate: rehearse the corrected migration with the real prerequisite schema in staging, test authenticated admin/staff workflows, review advisors, then install it as part of the authorized combined release before deploying dependent UI. Do not silently mark these cards production-ready from widget or fixture tests.

Progress after these additions: 52 published improvements + 14 draft improvements = 66 of 98; 32 remain outside the improvement batches. Batch 1: 13/23; Batch 2: 1/23. These counts do not represent complete domain workflows. Prior financial, permissions, translation and deployment gaps remain.

Verified code head: 10fb935beb2e0ff01d766682c2d4342fd02d0218. Run 39039723097 passed flutter analyze, the full Flutter test suite, release web build, and isolated PostgreSQL task-contract checks. Eight new unit/widget tests cover parsing, authorized sources, pending/history, source failures, permission changes, assignment retries, report permissions, mobile RTL and Dashboard route scoping.

## Feedback and attendance checkpoint — 17 October 2026

Four additional unique Dashboard routes now have draft implementations across two workflows:
- Customer Feedback and Feedback share a dedicated staff-captured feedback register: complaint/suggestion/compliment, optional customer name and 1–5 rating, open/review/resolved history, required resolution notes, administrator-only dismissal/reopening, search and status/category/date filters.
- Employee Attendance and Attendance share a server-timed self-service clock register. Employees can clock only themselves and see only their own attendance; administrators can view all recorded sessions. One open session per employee, overlap-based Baghdad date filtering, clipped recorded duration and explicit open-session snapshot time. A current own session remains available for clock-out even when it started outside the selected dates.

New backend migration: supabase/migrations/20261017141724_cafe_feedback_attendance.sql, filename generated by Supabase CLI. Dedicated feedback and attendance tables have RLS enabled and no direct client privileges. Private implementations enforce authenticated staff profile, AAL2, relevant Dashboard card permission, actor-bound request identity, row versions and audit history. Public wrappers run as invoker. Attendance locks the employee before capturing wall-clock server time, preventing duplicate open sessions and avoiding pre-lock timestamps. Read workspaces use stable snapshots.

Both UIs include confirmation, exact-request retry after an ambiguous response, stale-data removal, preserved search text, and explicit database-unavailable states. Retry identity is kept only while the screen remains mounted. The newest 500 records are shown with an explicit truncation warning and total count; at most 31 calendar dates may be requested. History displays the latest 100 events for loaded records and says when earlier history is outside this window. Unrated feedback is not averaged as zero.

Scope limits: feedback is manually recorded by staff; public QR submission, per-product surveys, employee reviews and attachments are not implemented here. Attendance is a clock register, not shift scheduling, breaks, payroll, absence detection, administrator corrections, or offline clocking. The general permission-profile read-only/time-history restrictions remain unfinished; the 31-day query limit is not a substitute for them. Kurdish/Arabic translations for new strings need review.

The new migration remains undeployed. Existing task migration deployment blocker remains. No production schema/data writes, merge or deployment occurred. Before publication, rehearse both pending migrations against real staging prerequisites, run Supabase advisors there, verify signed-in admin/staff and AAL2 behavior on devices, and apply approved migrations before dependent UI. PostgreSQL contract tests use isolated auth/permission fixtures and do not replace that acceptance gate.

Progress: 52 published improvements + 18 draft improvements = 70/98; 28 remain outside these batches. This is a count of improved card routes, not full workflow completion. Batch 1: 17/23; Batch 2: 1/23.
Batch 1 still outstanding: Minibar Live Board, Low Stock, Nargile Orders, Notifications & Alerts, Customers, Events.
Batch 2 still outstanding: its original list except Reports (22 cards).

Verification: code head 5cea99d3ae85b8fda034ede5a01d6edb8843d6b3 passed Flutter analysis, full Flutter tests, release web build and isolated PostgreSQL contracts in run 39040857816. Eleven new unit/widget tests cover review actions, malformed data, missing ratings, truncation, failed refresh, form validation, command retries, resolution notes, self-clock identity, record history, mobile RTL and all four Dashboard routes. Database tests cover MFA/card denial, actor-bound retries, invalid ratings, review versions/notes, attendance ownership, one open session, server-time-only input, audit entries, authenticated wrappers, direct/anonymous denial, Baghdad midnight clipping and the 500-row limit. No authenticated staging/device acceptance test is claimed.

## Inventory and purchasing checkpoint — 17 October 2026

Seven additional unique Dashboard routes have draft implementations:
- Inventory Overview: administrator item setup, units and departments, reorder thresholds, one-time opening stock, recorded balances and movement history.
- Low Stock: Kitchen & Minibar stock at or below its reorder threshold, excluding general supplies.
- Low Stock Alerts: low stock across all departments.
- Purchase Requests: single-item requests with supplier name, quantity, notes and status history.
- Pending Approvals: administrator approval/rejection of requested quantities.
- Supplier Deliveries: approved outstanding quantities, partial/full physical receipts, reference notes and receipt history. Administrators with approval access can cancel outstanding quantities without reversing stock already received.
- Inventory Waste: quantity and mandatory reason, with server checks preventing negative stock and retained movement history.

All seven routes preserve Style 2 and existing Dashboard visibility checks. Search runs on the server and remains populated after refresh. Explicit totals and 500-record limits disclose coverage. Failed reads clear stale records and disable writes. Forms validate decimal quantities, require movement reasons, and confirm actions. Ambiguous retries reuse the same request ID and expected version while the screen is mounted.

New undeployed migration: supabase/migrations/20261017143246_cafe_inventory_purchasing.sql (Supabase CLI-generated filename). Dedicated stock, purchases and immutable movement tables have RLS enabled and direct client privileges revoked. Private commands enforce authenticated staff profile, AAL2, specific action permission, administrator-only setup/approval, row versions, actor-bound retry identity and atomic stock/movement/audit writes. Units cannot change after a movement or purchase request. Public wrappers use invoker security. Database testing found and corrected an ambiguous note variable and its table-constraint reference before this checkpoint.

Scope limits: this is a recorded quantity ledger, not automatic recipe/order consumption or inventory valuation. Requests contain one item and a supplier name; supplier master records, multi-line purchase orders, prices, invoices, payments, returns/reversals, attachments and automatic purchasing are not implemented. Movement history is visible; full private audit-event browsing is not. Search exposes up to 500 matching rows without pagination. General permission-profile read-only/time-range enforcement, translation review and durable offline retries remain separate unfinished work.

No production schema/data changes, merge or deployment occurred. The task, people and inventory migrations must be rehearsed with real staging prerequisites, advisors and authenticated admin/staff device checks before the combined release. Isolated PostgreSQL auth/permission fixtures and mocked Flutter RPCs do not replace this acceptance gate.

Progress: 52 published improvements + 25 draft improvements = 77/98; 21 remain outside the improvement batches. These counts describe improved card routes, not complete domain workflows. Batch 1: 18/23; Batch 2: 7/23.
Remaining Batch 1 (5): Minibar Live Board, Nargile Orders, Notifications & Alerts, Customers, Events.
Remaining Batch 2 (16): Invoices, Discounts, Credit Accounts, Confirm Credit, Accounts Receivable, Credit Collections, Credit Approval History, Cash Transfers, Staff Performance, System Health, Backup & Sync Status, Dashboard Personalization, Security, Backup, Offline Mode, Personalization.

Verified code head: 6b2c24127e69b162c2c861706212b84c1a17fcbf. Run 39042117955 passed Flutter analysis, the full Flutter test suite, release web build and isolated PostgreSQL 17 task, people and inventory contract checks. Twelve new inventory unit/widget tests accompany the database checks. No authenticated staging/device acceptance is claimed. The following checkpoint change is documentation only.

## Personalization checkpoint — 17 October 2026

Two additional Dashboard routes, Dashboard Personalization and Personalization, now open the existing permission-scoped Favorites manager rather than generic records/design content. The same improvements apply to the Dashboard Favorites home area.

Implemented: add/remove authorized cards across sections; preserve saved order; move favorites earlier/later using accessible arrow controls; refresh saved preferences; confirm or cancel a reset that explicitly includes currently hidden saved cards. New entries append instead of alphabetically sorting the list. Reordering preserves hidden saved entries. Stored IDs never grant access: only current authorized cards render, and navigation rechecks permissions.

Asynchronous reads/writes capture their original account and storage instance. Changing account/storage clears prior content and invalidates late results. Failed refreshes clear stale cards and disable preference writes until reloaded. Changes read current storage before applying the requested operation, preserving previously saved entries and ordering; this is not an atomic cross-tab transaction.

Scope: preferences remain on this browser/device using the existing account-scoped storage. These controls order Favorites only, not main Dashboard categories. Cross-device synchronization, custom card colors and broader Dashboard layout settings remain unfinished. Translation review remains pending. No database migration or production change was made for this checkpoint.

Progress: 52 published improvements + 27 draft improvements = 79/98; 19 remain outside the improvement batches. Batch 1 remains 18/23; Batch 2 is 9/23. These are improved route counts, not completed domain workflows or release readiness.
Remaining Batch 1 (5): Minibar Live Board, Nargile Orders, Notifications & Alerts, Customers, Events.
Remaining Batch 2 (14): Invoices, Discounts, Credit Accounts, Confirm Credit, Accounts Receivable, Credit Collections, Credit Approval History, Cash Transfers, Staff Performance, System Health, Backup & Sync Status, Security, Backup, Offline Mode.

The combined release remains unpublished. Prior migration/staging/authenticated-device acceptance gates and financial, permission, language and offline gaps still apply.

Verified code head: cd5e917acba8c1a38a94b14a3cf89742feb1aa83. Run 39043548262 passed Flutter analysis, the full Flutter test suite, release web build and isolated PostgreSQL contract checks. Eight new personalization tests cover saved ordering/reopening, reset confirmation, late account reads, permission removal, failed refresh, fresh-read merging, mobile RTL and both Dashboard routes. Full-suite testing caught and fixed unavailable device-storage initialization before completion. No authenticated staging/device acceptance is claimed. The following checkpoint commit changes documentation only.
https://github.com/zanyarsidqi-sys/Gelye-Sherane-Caf-Rest/actions/runs/39043548262
