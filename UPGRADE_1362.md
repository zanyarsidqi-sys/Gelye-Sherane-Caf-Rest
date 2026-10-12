# Upgrade 1362: Filtered payment-preparation draft totals

Added read-only cash/credit/electronic method and status filters to the existing motel-food payment preparation draft list. Added its aggregate after the rendered draft rows, with record count. Missing/invalid amounts show unavailable, not an incorrect total. These are draft intent amounts, explicitly not received revenue. The existing posted finance invoice date/employee/method filters and bottom total remain intact. No invoice printing or cash settlement permissions changed.

Cross-section boundary: motel-food draft RPC vs posted invoice RPC; no assumption that draft amounts represent actual cash/credit settlements. Full dashboard card filtering, cash/credit subtypes, invoice export and server integration remain pending.
