# Phase 1 Steps 65–68 — Protected route recovery (Rest)

Actual code modified: `lib/app/cafe_app.dart`.

- 65: Explicit protected-route permission recheck for transient failures.
- 66: Avoid background-triggered verification from authentication events.
- 67: Recheck session identity before retry; never transfer route to another employee.
- 68: Show permanent session-ended message and suppress retry after identity termination.

No SQL migrations changed. Flutter/Dart SDK and live Supabase tests are required to verify runtime behavior.
