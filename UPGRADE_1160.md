# Upgrade 1160 — Kitchen confirmation invalidation on refresh

Manual or automatic queue refresh invalidates the outstanding confirmation token and clears the confirmation lock. The final pre-RPC check also validates the confirmation token, preventing a dialog opened for an earlier queue snapshot from advancing an order after refresh. This is source-level testing only; live Flutter and Supabase verification are deferred.
