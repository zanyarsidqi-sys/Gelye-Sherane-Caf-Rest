# Upgrade 1267 — Dashboard empty-response handling

Prevent null assertion when a completed live Dashboard request has no data snapshot. Display explicit empty response state and a retry action for empty maps, preserving permission checks, loading, error and existing cards.

Verification: static source assertions and ZIP integrity; Flutter and Supabase runtime unverified.
