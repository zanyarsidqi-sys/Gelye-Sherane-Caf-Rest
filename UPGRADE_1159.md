# Upgrade 1159 — Kitchen status-operation identity

Added a monotonically increasing operation token for Kitchen status RPCs. An earlier
request cannot clear the busy indicator belonging to a later request for the same
order and employee (including account-switch/re-login scenarios). Auth changes and
widget disposal invalidate pending tokens.

Tests: source regression checks only. Flutter and Supabase acceptance deferred.
