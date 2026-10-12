# Dashboard Coding Upgrade 36 — Table Service Task Foundation

- Added `lib/screens/dashboard/table_service_tasks_panel.dart` with a permission-dependent, read-only service task queue, status filters, table context, assignee, priority, quantity, notes and timestamps.
- Defined request types for extra tissues, forks, spoons, knives, plates, glasses, chairs, water, condiments, waiter calls, dish pickup, shisha pickup/service, cleaning and custom requests.
- RPC `gs_dashboard_table_service_tasks` is a **contract only**: it has NOT been deployed or implemented in the backend. The panel fails closed if unavailable.
- Future backend work: customer QR request creation, cashier assignment, employee notifications, audit trail, task acceptance/completion, idempotency, shisha order linkage, and table release only after departure, full confirmed settlement and required cleanup.
- No fabricated task data, no unsafe direct writes, no claim of verified Flutter/Supabase behavior.
- This increment addresses newly agreed service requests. Final Dashboard review and iPhone/Windows design previews remain pending.
