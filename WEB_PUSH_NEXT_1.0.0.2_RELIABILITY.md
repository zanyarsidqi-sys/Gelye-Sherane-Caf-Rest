# Web Push reliability follow-up — Release 1.0.0.2 candidate

- Fixed device opt-out sequencing: revoke the authenticated server subscription before deleting the local PushManager subscription. This prevents a failed server request from silently leaving an orphaned server registration while the user is told notifications are off.
- Fixed device re-enrollment sequencing: revoke the old server subscription before unsubscribing locally and replacing it. On failure, preserve the old local subscription for retry.
- Added regression tests for successful ordering and failed server revocation. Node browser push tests: 12 passed, 0 failed.
- No Supabase migrations executed, secrets configured, website deployed, or production push delivery verified. Existing candidate version remains 1.0.0.2; do not announce a new release until approved and live deployment verified.
