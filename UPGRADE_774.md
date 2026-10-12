# Upgrade 774 — Session events use authoritative current user

Section: shared_access

Acceptance checkpoint: verify `final nextUserId = Supabase.instance.client.auth.currentUser?.id;` in `lib/shared/section_shell.dart`.

Result: PASS in static source inspection. This does not establish Flutter runtime behavior, Supabase security, or production readiness.

Implementation: changed the shared section authorization listener to use `auth.currentUser?.id` instead of potentially absent event session user IDs.
