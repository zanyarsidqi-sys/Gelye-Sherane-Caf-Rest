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
