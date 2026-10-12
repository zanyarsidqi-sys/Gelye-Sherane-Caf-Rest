# Upgrade 273 - Customer feedback staff review

Added a read-only customer-feedback dialog to the existing employee Recommendations tab.
Uses the permission-checked gs_staff_customer_feedback_list RPC from migration 272.
Displays survey ratings, item ratings, suggestions and new-product requests.
Customer submissions remain disabled until table-visit-scoped authorization and anti-spam are implemented.
This does not implement status changes for feedback rows or merge them into the earlier recommendations table.
No Flutter compilation or live Supabase testing performed.
