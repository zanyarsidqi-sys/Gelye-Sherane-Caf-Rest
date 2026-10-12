# Upgrade 458 — Customer Safety Hold Acknowledgement Guard

- Added a database trigger to reject new/updated customer `acknowledged` responses on identity onboarding requests with an existing safety hold.
- Added a customer-owned v2 onboarding response RPC that returns `hold_active` without revealing other users’ records.
- Updated the customer interface to display active holds, hide acknowledgement actions for held requests, and refresh after a hold is submitted.
- Preserved existing RPCs and all project files. No verified identity activation, payment consent, or credit debit is enabled.

Flutter compilation and live Supabase migrations were not executed. Apply and test migrations in sequence before deployment.
