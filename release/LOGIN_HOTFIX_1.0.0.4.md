# Login configuration hotfix 1.0.0.4

The live 1.0.0.2 JavaScript initializer contained a non-API-key value.
Its request to the configured Supabase Auth settings endpoint returned HTTP
401 with "Invalid API key". No employee credentials were used in diagnosis.
The repository public client key was accepted by the same endpoint.

The GitHub production repository secret was replaced with the verified
publishable key. Existing deployed bundles do not pick up secret changes:
a new approved build and deployment are still necessary.

This patch validates key format, project identity, API acceptance and email
provider availability before production compilation. It does not weaken MFA,
employee authorization, or deployment approval requirements.

Version 1.0.0.4 keeps the unrelated 1.0.0.3 dashboard draft separate.
Employee password/MFA login and production deployment remain unverified until
performed; a passing public settings check is not an employee login test.
