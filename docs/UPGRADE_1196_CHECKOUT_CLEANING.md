# Upgrade 1196 — Post-checkout task queue integration

The existing cash-only, payment-guarded checkout flow creates physical cleaning tasks in `gs_table_service_tasks`. This migration mirrors newly created cleaning, dish pickup and shisha pickup tasks to the Section 05 service queue, once per source task. Kitchen completion also marks the authoritative physical task complete.

The source table's existing settlement and cleaning gates remain authoritative; the bridge does not release tables, accept payment, or mark visits closed. Shisha pickup is mapped to the existing `dish_pickup` task category and explicitly labeled in notes.

Limitations: The trigger applies to **newly created** source tasks after migration; it does not backfill older tasks. A Kitchen cancellation does not cancel mandatory physical cleaning. Live SQL migration, RLS, end-to-end checkout, and Flutter tests are deferred.
