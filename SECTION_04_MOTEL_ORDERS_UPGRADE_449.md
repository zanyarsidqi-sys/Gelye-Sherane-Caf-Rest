# Upgrade 449 — Enforce Customer Safety Holds Across Identity Reviews

Added a shared database trigger that rejects writes to onboarding evidence reviews, final identity assessments, external evidence intake and external evidence reviews when the customer has raised a safety hold. The trigger locks the parent onboarding request, serializing staff writes with customer safety-hold creation and avoiding a race. Existing history is retained. Holds cannot be removed through staff RPCs. No customer identity activation, consent or credit debit is enabled.

**Testing:** ZIP integrity verified; Flutter compilation and live Supabase migration execution were not available.
