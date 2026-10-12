# Upgrade 266 — Instruction edit revision queue

Added a guarded RPC `gs_edit_unaccepted_item_with_revision` which delegates to the existing strict pre-acceptance instruction edit function, then atomically records old/new instructions and enqueues staff/customer update events. A failed edit rolls back all events. Legacy direct execution is revoked to prevent bypass.

**Not implemented:** editing quantities/products after preparation, delivering queued notifications, printer worker and physical revised tickets, customer QR order submission, Flutter UI integration, or Supabase deployment. This RPC intentionally does not generate a revision print ticket for a not-yet-accepted item; its original preparation ticket will carry the final instructions.
