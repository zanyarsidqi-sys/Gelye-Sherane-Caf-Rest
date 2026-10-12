# Dashboard Upgrade 1282

## Fix
Rebuild the Dashboard after both coordinated Supabase requests settle and the refresh lock is released, when no follow-up refresh is queued. This allows retry actions disabled during a pending request to become enabled after a failed or empty response, without requiring another unrelated UI change.

## Scope
Only `lib/screens/dashboard/dashboard_screen.dart` changed. Existing source, RPCs, permissions, and screens retained. Static source and ZIP integrity checks passed. Flutter compilation and Supabase runtime testing were not available.
