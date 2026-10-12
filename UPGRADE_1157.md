# Upgrade 1157 — Kitchen confirmation lock isolation

Fixed a cross-session race: a confirmation started by employee A could finish
after employee B started a new confirmation for the same order, clearing B’s
lock. Each confirmation now receives a monotonically increasing token.
Account switching and disposal invalidate earlier tokens; only the owning
confirmation may release its lock.

Source regression only; Flutter and Supabase runtime verification deferred.
