# Upgrade 689 — Inventory history session refresh

## Defect
The inventory history dialog was not subscribed to auth changes. Parent-screen refreshes do not necessarily rebuild an open dialog, so history belonging to a previous employee could remain displayed after account switching.

## Change
Wrap the existing cached FutureBuilder in a StreamBuilder subscribing to Supabase auth changes. Re-check employee identity before showing history and after completion. Retain the single history request created outside the dialog builder to avoid duplicate requests.

## Verification
Three source-level regression checks. Flutter compilation and live account-switch testing are still required.

## Progress
No verified completion percentage change. Section 03 remains at the earlier estimated 76%; Section 07 remains unverified.
