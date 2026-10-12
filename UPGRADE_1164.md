# Upgrade 1164 — Kitchen filter change cancels stale confirmations

Changing the status filter now invalidates any open handover confirmation and
clears the confirmation lock, matching the existing refresh behavior. The
confirmation token and queue-generation checks prevent an old dialog from
submitting a status change after the employee changes the view.

This is source-level validation only; Flutter and live Supabase checks are
deferred at the user’s request.
