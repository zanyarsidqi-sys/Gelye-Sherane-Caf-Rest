# Phase 1 Step 27 — logout and stale authorization hardening

Changed `lib/app/cafe_app.dart` to invalidate pending authorization responses on lock/auth events, prevent authorization while logout recovery is required, retry failed sign-out, and rerun a fresh permission check after an invalidated response.

Static checks passed. Flutter compilation and real Supabase session testing remain pending.
