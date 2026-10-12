# Upgrade 261 — Limited secure editing

Implemented a server-side, authorized and audited change to **preparation instructions only**, before an order item is accepted or a kitchen ticket exists. Requires an open table visit and `table_orders.can_edit`; rejects locked discounted invoices; optimistic concurrency compares the prior instructions. Audit rows record the actor and before/after values. Does not alter amounts.

Not implemented: product/quantity changes, editing after preparation starts, kitchen revision tickets, full employee edit form, production migration tests. Do not describe this as complete pre-delivery order editing.
