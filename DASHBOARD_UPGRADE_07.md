# Dashboard coding upgrade 07

Added `lib/screens/dashboard/table_guest_adjustment.dart`.

- Separate controls for additional customers and extra chairs.
- Optional name per joining customer.
- Emits a typed request; does NOT silently mutate database or mark payment as complete.
- Caller must use a permission-checked atomic backend operation to enforce capacity, update guest count and audit changes.
- Not yet wired to the live Dashboard or Tables screen because the current backend has no verified guest-adjustment RPC contract.
- Compilation, integration and Supabase testing deferred by request.

Overall Phase 3 remains ~54% (previous estimate, not measured).
