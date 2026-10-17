# Approved Dashboard design review — 17 October 2026

User approved the proposed direction for all 96 Dashboard card detail screens. Approval authorizes development; it does not authorize production publication. The generated mockups are concept illustrations, not screenshots or executable acceptance criteria.

## Corrections that override generated samples

- Customer refunds are cash out, never non-order cash in.
- Preserve actual pricing modes: Normal, Tourism, Owner, Discount; no invented Agency/VIP modes.
- Never add unlike stock units together.
- Backup sizes are bytes/MB/GB, never IQD.
- Badini remains the first-use default; saved language choices take priority.
- Sample timestamps, names, amounts, counts, permissions and status indicators are not verified business data.
- Unknown guest counts remain unknown, not fabricated numeric guests.
- Standing Cash is unpaid active table bills in the approved proposal. Existing cash-journal routing has NOT yet been replaced.
- All actions require existing or explicitly implemented server authorization, validation and audit. Mockup buttons do not establish implemented capability.

## Development batch 1

Implemented shared report screen changes used by 28 Dashboard report routes: executive styling, mobile labeled-record layout, optional inherited date-range support (Dashboard caller hookup blocked), request-race protection, stale-data removal on refresh/error, data-shape validation, refresh timestamp, translated title/controls, filtered PDF export.

Automatic approval review rejected the staff_dashboard_page.dart full-file write twice, including after exact inverse-substitution evidence. The available connector replaces whole files; no narrow write API is available. That file remains unchanged. Report initialRange support is tested independently, but Dashboard navigation still starts at today's default until the caller hookup is permitted.

No invented financial aggregates, no database changes, no permissions changes, no deployment. Remaining cards and domain-specific report designs are pending. This is not completion of the 96 cards.

Validation: five new widget tests plus existing report regression test; CI result recorded in the draft pull request.

## Approved card-by-card direction

### Favorites — part 1

1. **Today Revenue** — Sales summary; gross sales, discounts, net sales; separate payments and refunds by receipt date; transaction list; actions: Dates, View transactions, PDF. Improvement: retain Dashboard period.

2. **Tables Occupied** — Occupied table list with table number, area, guests, elapsed time, order balance, service status; actions: Area filter, Open table. Improvement: distinguish paid-still-seated from unpaid.

3. **Kitchen Orders** — Orders grouped waiting/preparing/ready, station and elapsed timers; actions: Station filter, Open order. Improvement: oldest waiting first.

4. **Pending Payment** — Unpaid motel and online orders, order reference, payer, original amount, paid, balance; actions: Source filter, Open order, Receive payment if authorized. Improvement: exclude table debt.

5. **Today’s Orders** — Today's order list across sources with reference, time, source, status, net amount; actions: Status filter, Open order. Improvement: exclude cancelled orders from sales total.

6. **Today’s Customers** — Recorded guest counts by source and visit; show unknown party sizes separately; actions: Source filter, Open visit. Improvement: do not count order quantity as guests.

### Favorites — part 2

7. **Motel Orders** — Motel order list with room, scheduled delivery, prepaid/pay-on-delivery badge, stage; actions: Room filter, Open order. Improvement: prevent charging prepaid food twice.

8. **Online & Walk-In Orders** — Separate Online and Walk-in tabs, pickup/delivery time, stage, unpaid balance; actions: Open order, Filter. Improvement: retain source distinction.

### Payments & Finance — part 1

9. **Standing Cash** — Standing Cash means unpaid active table bills; table, visit, net bill, paid, remaining; actions: Open table, Receive payment if authorized. Improvement: separate this from register cash.

10. **Invoices** — Invoice list with reference, table/source, date, total, payment status; actions: Search, Open invoice, Print. Improvement: immutable issued invoice history.

11. **Discounts** — Applied discounts with order, type, amount, approver, reason; actions: Filter, Open order. Improvement: enforce discount limits server-side.

12. **Credit Accounts** — Customer credit accounts with limit, outstanding, overdue, last payment; actions: Search, Account detail. Improvement: real credit ledger, not notes.

13. **Cash Reconciliation** — Register and shift, expected cash, counted cash, difference; actions: Count cash, Submit reconciliation, History. Improvement: preserve snapshot; no silent balance changes.

14. **Cash Out — Owner** — Owner cash withdrawal requests with amount, source register, handover employee, owner receipt, status; actions: Request, Review, Confirm receipt. Improvement: distinguish owner withdrawals from expenses.

### Payments & Finance — part 2

15. **Cash & Payment Methods** — Payments grouped by method; gross receipts, refunds, net received; actions: Date range, Method detail, Export. Improvement: reconcile payment transactions.

16. **Refunds & Adjustments** — Refund list linked to original payment with reason, amount, approval and timestamp; actions: Open original, Request refund. Improvement: prevent over-refund and duplicate retries.

17. **Daily Financial Summary** — Daily summary separates net sales, received payments, refunds, unpaid amounts, expenses, owner withdrawals; actions: Pick day, Print. Improvement: show source definitions.

18. **Expenses** — Expense records supplier, purchase date, amount, paid, remaining, evidence; actions: Add expense, Attach receipt, Record payment. Improvement: upload never marks paid.

19. **Remaining Cash** — Recorded register balance with opening funds, receipts, refunds, paid expenses and owner withdrawals; actions: Register filter, Journal, Reconcile. Improvement: recorded cash is not physical count.

20. **Confirm Credit** — Pending customer credit requests with customer, invoice, requested amount, limit and reason; actions: Approve, Reject. Improvement: separate approval from collection.

### Payments & Finance — part 3

21. **Cash Received** — Payment receipts by timestamp, order, method, amount, employee; actions: Dates, Search, Open receipt. Improvement: label all-method collections clearly.

22. **Cash In** — Non-order register cash deposits with source, reason, receipt, employee; actions: Record cash in, History. Improvement: never duplicate customer order payments.

23. **Pending Expenses** — Unpaid and partially paid expense list, supplier, due date, balance; actions: Open expense, Pay if authorized. Improvement: distinguish unpaid from awaiting approval.

24. **Accounts Payable** — Supplier balances with invoices, due dates, paid and outstanding; actions: Supplier detail, Invoice detail. Improvement: reconcile to purchasing ledger.

25. **Accounts Receivable** — Customer amounts owed with invoices, due dates and balance; actions: Customer detail, Record collection. Improvement: keep separate from supplier liabilities.

26. **Credit Collections** — Credit collections linked to account and invoice with amount, method, allocation; actions: Record collection, Receipt. Improvement: do not record a second sale.

### Payments & Finance — part 4

27. **Credit Approval History** — Credit decision history with requester, reviewer, time, amount, reason; actions: Search, View decision. Improvement: preserve immutable audit.

28. **Cash Transfers** — Register-to-register transfer detail with source, destination, amount, sender, receiver and status; actions: Request transfer, Confirm receipt. Improvement: balanced paired entries.

29. **Expected vs Actual Cash** — Cash count snapshots show expected, counted, variance, employee, time and explanation; actions: Open count, Review variance. Improvement: compare same register and instant.

30. **Financial Alerts** — Exceptions list: negative balance, overdue approvals, reconciliation variance; severity, evidence and assignment; actions: Open issue, Assign, Resolve. Improvement: alerts link to source records.

### Tables & Reservations — part 1

31. **Live Tables** — Live table overview with area, occupancy, pricing mode, guest count, elapsed visit and balance; actions: Open table, Show QR. Improvement: paid-still-seated remains occupied.

32. **Table Reservations** — Booking list with time, table, party, arrival state; actions: Search, Open booking, Check in. Improvement: detect conflicting allocations.

33. **Available Tables** — Available tables by area and capacity with next reservation; actions: Party-size filter, Open table. Improvement: account for upcoming bookings.

34. **Waiting List** — Waiting parties with queue time, party size, requested area and assignment; actions: Add party, Assign table, Mark left. Improvement: preserve queue history.

35. **Guest Check-In** — Expected arrivals with booking reference, party, table and arrival time; actions: Arrived, No-show with reason. Improvement: prevent duplicate active visits.

36. **Table Cleaning** — Cleaning jobs with table, assigned staff, duration and checklist; actions: Assign, Start, Mark clean. Improvement: keep table unavailable until completed.

### Tables & Reservations — part 2

37. **Table Service Requests** — Table service requests with type, table, guest note, age and owner; actions: Accept, Assign, Complete. Improvement: prevent two staff accepting simultaneously.

38. **Guests Today** — Guest visits with recorded party size and arrival date; source filters and unknown-count warning; actions: Open visit, Export. Improvement: count visits consistently.

39. **Table Map** — Interactive area plan with table shapes, chairs, status, mode-colored borders; actions: Area selector, Open table, Authorized edit layout. Improvement: saved positions match live tables.

40. **Reservations** — All bookings with calendar/list, status, party and table allocation; actions: Open booking, Reschedule, Cancel with reason. Improvement: same records as Table Reservations.

41. **Cleaning Needed** — Tables awaiting cleaning with checkout time, dish/shisha pickup tasks and assignee; actions: Open task, Assign. Improvement: share cleaning workflow.

42. **Table Occupancy** — Occupancy report with occupied and available counts, capacity and duration by area; actions: Date range, Table detail. Improvement: label live occupancy versus historical utilization.

### Kitchen & Minibar — part 1

43. **Kitchen Live Board** — Kitchen station board with waiting, preparing, ready columns and ticket items; actions: Station filter, Open ticket, Allowed status action. Improvement: preserve revisions.

44. **Minibar Live Board** — Dedicated drinks and Nargile station tabs with preparation queues; actions: Station selector, Open ticket. Improvement: separate preparation routing.

45. **Orders Preparing** — Preparing orders with station, started time, target and elapsed timer; actions: Open order, Mark ready if authorized. Improvement: changes checked against current status.

46. **Ready for Delivery** — Ready orders with ready-since time, table/room/delivery destination and assigned runner; actions: Assign runner, Confirm handover. Improvement: record handover separately from delivery.

47. **Delayed Orders** — Orders beyond configured target with stage, elapsed time and assigned staff; actions: Open order, Escalate. Improvement: explain delay threshold.

48. **Station Printers** — Printers by station with last verified contact, queued tickets, failures; actions: Test print, Retry with confirmation, Open ticket log. Improvement: distinguish unknown from online.

### Kitchen & Minibar — part 2

49. **Menu Availability** — Products grouped available/unavailable by station; actions: Search, Set availability if permitted. Improvement: reflect changes on customer menu.

50. **Menu** — Product list with category, price modes, image and availability; actions: Search, Open product. Improvement: reuse actual menu workspace.

51. **Low Stock** — Stock below item threshold with unit, available quantity and location; actions: Open item, Request purchase. Improvement: use stock ledger, not manual summary.

52. **Nargile Orders** — Nargile tickets with flavor, table, preparation stage and coal requests; actions: Open order, Assigned actions. Improvement: route only to Nargile station.

53. **Kitchen Queue** — Station queues ranked by received time, priority and readiness; actions: Filter station, Open ticket. Improvement: no duplicate ticket counting.

### Orders & Customer Service — part 1

54. **Table Orders** — Dine-in orders grouped by active table visit with item status and payment balance; actions: Open order, Open table. Improvement: preserve visit linkage.

55. **Motel Orders Tracking** — Motel orders with room, schedule, fulfillment stage and prepaid badge; actions: Filter, Open order. Improvement: track scheduled versus immediate work.

56. **Online Orders Tracking** — Online orders with fulfillment method, promised time, stage and balance; actions: Open order, Permitted status action. Improvement: auditable handover.

57. **Walk-In Orders Tracking** — Walk-in orders with pickup reference, time, preparation status and payment; actions: Open order, Confirm pickup if permitted. Improvement: verify correct order.

58. **Customer Requests** — Guest requests with table, type, submitted time, notes and employee assignment; actions: Accept, Assign, Complete. Improvement: timestamp every transition.

59. **Customer Feedback** — Feedback detail with rating, item/table reference, comment, review state; actions: Filter, Assign follow-up, Mark reviewed. Improvement: protect customer information.

### Orders & Customer Service — part 2

60. **Service Speed** — Service durations: received-to-accepted, preparation, ready-to-delivered with sample counts; actions: Date range, Open slow order. Improvement: no invented timestamps.

61. **Today Orders** — Today's orders list, source and stage filters, totals excluding cancelled sales; actions: Search, Open order. Improvement: share Today's Orders workflow.

62. **Online Orders** — Online order list with pickup/delivery tabs and status; actions: Search, Open order. Improvement: share tracking records.

63. **Takeaway & Delivery** — Takeaway and delivery tabs with promised time, pickup/delivery status and assignee; actions: Open order, Assign delivery. Improvement: separate from seated visits.

64. **Feedback** — Customer feedback list with rating, comment and follow-up state; actions: Open feedback, Review. Improvement: same underlying feedback workflow.

### Employees & Operations — part 1

65. **Employee Attendance** — Attendance by employee with shift, clock-in/out, late and missing entries; actions: Date, Employee detail. Improvement: audited corrections.

66. **Employee Assignments** — Assignments by employee with table/station, shift, open workload and priority; actions: Assign, Reassign. Improvement: avoid conflicting assignments.

67. **Pending Staff Tasks** — Staff task queue with unassigned, overdue and in-progress tabs; actions: Assign, Open task. Improvement: due dates and ownership.

68. **Staff Performance** — Performance summary with completed tasks, response time and sample count; actions: Date range, Evidence detail. Improvement: contextual measures, no unsupported ratings.

69. **Maintenance Requests** — Maintenance requests with asset, severity, reported time and assigned worker; actions: Open request, Assign. Improvement: preserve evidence and status history.

70. **Notifications & Alerts** — Alerts inbox with severity, source, time, delivery status and acknowledgment; actions: Open source, Acknowledge. Improvement: acknowledge is not resolve.

### Employees & Operations — part 2

71. **Customers** — Customer directory with name, permitted contact and visit/order references; actions: Search, Open customer. Improvement: restrict private information.

72. **Employees** — Staff directory with name, department, role and active state; actions: Search, Open profile if allowed. Improvement: do not expose sensitive payroll here.

73. **Tasks** — Tasks with owner, due time, checklist and status; actions: Create, Assign, Complete. Improvement: shared task source.

74. **Events** — Event reservations with time, guest count, table allocation and approval status; actions: Open event, View availability. Improvement: do not confuse with staff events.

75. **Maintenance** — Maintenance work orders with asset, assignee, priority, evidence and completion; actions: Open work order, Update status. Improvement: link original request.

76. **Attendance** — Attendance history by shift and employee with corrections audit; actions: Date filter, View entry. Improvement: same attendance records.

### Employees & Operations — part 3

77. **Tourism Customers** — Tourism group visits with group reference, party size, table and active pricing mode; actions: Open visit. Improvement: derive group counts from recorded visits.

### Inventory & Purchasing — part 1

78. **Inventory Overview** — Stock summary by location with quantities, units, low stock and valuation basis; actions: Open location, Item search. Improvement: ledger-backed figures.

79. **Low Stock Alerts** — Low stock exceptions by item, location, threshold and available stock; actions: Open item, Purchase request. Improvement: combine duplicate alerts.

80. **Purchase Requests** — Purchase requests with requester, items, quantities, reason and approval state; actions: Create request, Review. Improvement: approved request is not received stock.

81. **Pending Approvals** — Inventory and purchasing approvals with type, requester, amount and evidence; actions: Review, Approve, Reject. Improvement: scope approvals by permission.

82. **Supplier Deliveries** — Expected supplier deliveries with purchase order, expected date, quantities received and outstanding; actions: Open order, Record receiving. Improvement: audit partial receiving.

83. **Inventory Waste** — Waste entries with item, unit, quantity, reason, location and approver; actions: Record waste, History. Improvement: posting updates stock exactly once.

### Reports & System — part 1

84. **Sales Performance** — Sales report by period and source with net sales, discounts, cancellations and comparison basis; actions: Filter, Transaction drill-down, PDF. Improvement: disclose definitions.

85. **Product Performance** — Product sales quantity, net sales, refunds and cost coverage; actions: Category filter, Product detail. Improvement: no profit claim without reliable costs.

86. **Table Occupancy Reports** — Table utilization report with occupied duration, available duration and visit counts; actions: Period, Area, Table detail. Improvement: define operating hours.

87. **Audit & Activity History** — Business audit log with actor, action, object, time and before/after changes; actions: Search, Open event. Improvement: immutable traceability.

88. **System Health** — Verified service checks with status, last check, failure detail and retry time; actions: Refresh diagnostics, Open incident. Improvement: show unknown when unverified.

89. **Backup & Sync Status** — Backup and sync summary with last verified backup, last sync, failed operations and timestamp; actions: View job log. Improvement: backup completion is not restore verification.

### Reports & System — part 2

90. **Dashboard Personalization** — Dashboard preferences: favorite cards, ordering, colors and visible groups; actions: Preview, Save, Reset. Improvement: per-employee persistence without expanding permissions.

91. **Reports** — Report catalog grouped sales, operations and finance with descriptions and permission-aware links; actions: Search, Open report. Improvement: consistent date ranges.

92. **Security** — Security overview with session/MFA status and permitted security events; actions: View sessions, Open event. Improvement: never expose secrets.

93. **Backup** — Backup job history with status, scope, size, timestamp and restore-test result; actions: View details, Authorized backup request. Improvement: guarded restore workflow.

94. **Offline Mode** — Connection status, queued operations, failed sync and last successful sync; actions: View queue, Safe retry. Improvement: idempotent retries, no fake offline capability.

95. **Audit & Activity** — Searchable audit events with actor, object, timestamp and change history; actions: Filter, Open event. Improvement: share audit source.

### Reports & System — part 3

96. **Personalization** — Display preferences: language, density and accessible contrast; actions: Preview, Save, Reset. Improvement: Badini default, saved selection preserved.


## Sources

- docs/section_card_inventory.json
- flutter_app/lib/staff_dashboard_page.dart
- User-approved visual review in this conversation (17 October 2026).
