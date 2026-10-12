# Upgrade 687 — Inventory session-bound overview

## Confirmed defect
The inventory overview FutureBuilder previously could render a cached response from employee A after the Supabase session changed to employee B. Other inventory operations had employee guards, but the overview did not.

## Change
- Subscribe to Supabase auth changes and reload the overview when the user ID changes.
- Bind overview requests to the employee who initiated them and reject results if that employee is no longer active.
- Guard both the inventory summary and product list against rendering stale employee data.
- Cancel the auth subscription on disposal.

## Verification
Static regression tests check the guards. Flutter SDK and a live Supabase instance are unavailable in this environment, so runtime and compilation checks remain outstanding.

## Completion measurement
This closes one identified source-level session-boundary defect in Section 07. It does not justify a percentage-point increase in verified section completion; all seven sections remain unverified in runtime.
