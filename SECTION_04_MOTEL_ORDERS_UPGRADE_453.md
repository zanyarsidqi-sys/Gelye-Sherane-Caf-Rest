# Upgrade 453 — Historical Safety Hold Employee Preflight

Added a Check Historical Safety Holds action for the entered customer and authenticated user UUIDs. Before creating a new identity onboarding request, the staff UI now checks historical safety holds and fails closed if the check fails or a hold is found. The server-side enforcement from Upgrade 452 remains authoritative. No identity verification, consent, or credit debit is enabled.

Flutter compilation and live Supabase migrations have not been tested.
