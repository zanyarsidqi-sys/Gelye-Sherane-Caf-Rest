# Upgrade 1252 - Kitchen source review and guarded operations

## Source changes
- Print-review list now clears cached ticket data before loading and on permission failure. Asynchronous results are discarded after employee identity changes or screen disposal.
- A review confirmation refuses to submit if the authenticated employee changes while the dialog is open. The server remains the authorization authority.
- Station creation disables concurrent submissions while the RPC is pending. The server still must enforce unique station keys and idempotency.

## Existing integration observed
- Kitchen is a 13-tab Section 05 screen; Stations, Product Routing, Station Staff, Station Devices, Print Review, and Station POS Accounts are inside Kitchen.
- Main Kitchen cards render authorized order-item guest labels and station names, with fallback text for absent values.
- The printer worker has uncertain-outcome handling; physical printing and ticket delivery are unverified.

## Remaining issues and deferred checks
- Review SQL RLS and SECURITY DEFINER permissions in staging, especially POS sessions, station provisioning, and review actions.
- Confirm employee account and device assignment behavior under revoked sessions and concurrency.
- Verify guest label projection and station mapping with actual multi-customer orders.
- Finance finalization is not yet connected to a validated POS/A4 PDF renderer; no financial mutations were added here.
- Flutter compilation, live Supabase, and physical printer testing explicitly deferred.
