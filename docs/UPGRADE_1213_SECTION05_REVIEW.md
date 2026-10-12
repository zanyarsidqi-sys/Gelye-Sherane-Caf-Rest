# Upgrade 1213 — Section 05 source-level integration review

## Corrections
- Table Orders replacement tracking now invalidates pending loads on widget disposal and ignores stale completion generations.
- Kitchen delivery action refresh no longer calls the general reload helper while its action busy flag is active; this prevents confusing refresh state and preserves the updated task list.
- Source-level regression checks cover the cross-section RPC references and the Kitchen delivery handoff methods.

## Integration boundary
- Existing SQL permission gates, payment correction logic and migration history are unchanged.
- No live database migration or Flutter compilation was performed.
- Review screens are conceptual; screenshots must be taken on actual iPhone and Windows builds after testing.

## Remaining checks before production
- Run `flutter analyze`, platform builds, and widget tests.
- Apply migrations to a staging Supabase project and exercise RLS with cashier, kitchen staff, supervisor and customer identities.
- Test real-time handoffs, offline reconnect, duplicate actions, corrected invoices, printer output and device notifications.
- Approve the iPhone and Windows interface designs before moving to Section 06.
