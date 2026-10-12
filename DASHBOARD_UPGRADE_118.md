# Upgrade 118 — Fix order-detachment checkout bypass

During the integration review, found a specific flaw in Upgrade 117: its
trigger checked only the **new** `table_visit_id`. A staff action could
change an order's visit ID to NULL or another visit while cash-only
checkout was counting attested orders. That could hide an unpaid order.

Upgrade 118 replaces the trigger function (the existing trigger remains
attached). It locks **both old and new visits**, rejects detaching from
closed visits, prevents moving independently cash-attested orders, and
checks that the destination is a valid occupied visit. This is an actual
source-code defect fix, not a new diagnostic function.

Still not production-ready: the table/visit/order lock ordering needs
concurrency testing, and legacy orders without `table_visit_id`, mixed
payments and reservation conflicts remain unresolved. No deployment or
Flutter compilation performed. ZIP integrity verified.
