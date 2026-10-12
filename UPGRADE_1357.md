# Upgrade 1357: Standing Cash item drill-down

Added an authenticated read-only Flutter order-item dialog to the existing Standing Cash ledger list. Uses the existing gs_finance_itemized_order_detail RPC and does not modify payment collection. Displays product, quantity, price, line total, recorded order timestamp and optional individual customer (not recorded when null). Order timestamp is not necessarily item-level timestamp. Online and motel linkage remains pending; no fabricated fields. Linked modules reviewed: dashboard, finance panel, payment RPC, motel source lists.

Validation: archive integrity and static source assertions only. Flutter and live Supabase unverified.
