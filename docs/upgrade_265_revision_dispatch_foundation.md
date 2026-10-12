# Upgrade 265 - Order change history and notification/print queue foundation

This adds locked-down database structures for original/updated item snapshots,
revision numbers, actor/timestamp, and deduplicated station-print, employee-
notification and customer-update dispatch tasks. It does **not** automatically
create revisions, notify employees or print tickets. These require a separately
implemented and tested transactional order-edit RPC and print worker.

Next: reconcile source schema and existing print queue, implement atomic editing
and outbox insertion with permission and checkout checks, then add worker routing,
retry/acknowledgment and station-specific change tickets. No public table token
may grant access to private revision data.
