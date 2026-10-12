# Upgrade 1135 — Section 05 Kitchen

Scheduled Motel Meals panel now invalidates its pending meal list and per-meal UI state when the authenticated employee changes, avoids stale action completion UI updates, and disposes its auth listener. Signed-out sessions see a sign-in prompt. Existing backend RPC authorization remains authoritative.

Verification: targeted static regression tests. Flutter compilation and live Supabase workflow not performed.
