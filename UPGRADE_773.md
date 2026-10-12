# Upgrade 773 — Inventory authentication event consistency

## Problem
The inventory auth-change listener compared `event.session?.user.id` against the active inventory employee. Some auth notifications can have a null session even when `auth.currentUser` remains populated, causing redundant inventory refreshes and unnecessary RPC calls.

## Change
The listener now compares `Supabase.instance.client.auth.currentUser?.id` to `_inventoryEmployeeId`, consistent with the actual stock request and widget authorization checks. Genuine sign-out or account switching still triggers a refresh.

## Evidence
Three static regression checks in `tests/integration/test_upgrade_773_auth_refresh.py`. These do not establish live Supabase behavior or Flutter compilation.

## Progress
Section 07: one source-level auth-refresh defect corrected. Overall section completion percentage remains unverified; no percentage increase claimed.
