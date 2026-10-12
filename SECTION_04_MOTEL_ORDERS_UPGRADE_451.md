# Upgrade 451 — Identity Activation Status in Employee Interface

Adds **Activation Status** to Credit Identity Onboarding, calling the protected `gs_staff_credit_identity_activation_status` RPC from Upgrade 450. Shows the onboarding state, customer safety hold, unavailable authoritative verification, and blocked identity activation/credit payment. Empty results and errors fail closed. Also repairs an existing undefined `id` reference in the Customer Safety Hold button callback by passing the row request ID.

No customer verification, consent, or credit debit is enabled. Flutter build and live Supabase testing remain outstanding.
