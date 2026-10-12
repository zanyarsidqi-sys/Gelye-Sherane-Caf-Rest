# Upgrade 583 — Server-filtered kitchen queue

## Issue
Upgrade 582 paginated all orders together, so a large number of completed orders could consume the 5,000-row limit and hide active kitchen orders. Switching status chips only filtered already downloaded records.

## Change
Apply the selected status filter at Supabase before paging: Active means new/preparing/ready; other status chips query their status, All has no status filter. Switching chips starts a fresh query and clears cached item requests. Preserve the bounded 5,000-row warning and existing status RPC.

## Verification
Static tests included. Flutter SDK and live Supabase runtime not available in this environment. Test against staging with >5,000 historical served orders and a newly created active order.
