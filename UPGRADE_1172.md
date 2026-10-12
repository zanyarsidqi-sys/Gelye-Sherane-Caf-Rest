# Upgrade 1172 — Deterministic Kitchen order sorting

Orders with identical created_at timestamps now use order ID as a stable tie-breaker
in both sort directions. This prevents apparent queue jumps during UI rebuilds.

All three Kitchen tabs and server-authorized handover are retained.
Source tests only; Flutter compilation and live Supabase testing are deferred.
Next: iPhone/Windows design preview and cross-section integration review.
