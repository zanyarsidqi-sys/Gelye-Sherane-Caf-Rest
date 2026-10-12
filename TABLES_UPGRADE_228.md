# Upgrade 228 — Selected POS Device Heartbeat

- Added per-user, per-Android-installation POS selection from manager-bound enabled registrations.
- Foreground heartbeat now sends a specific POS device ID and backend checks ownership and enablement.
- Revoked authenticated EXECUTE from old broad employee heartbeat function; prevents one account from marking all bound devices online.
- UI supports device selection, manual test and opt-in automatic heartbeat for selected device.
- Security limitation: an authenticated employee could still select another device bound to their account. This is NOT cryptographic device identity or hardware attestation; production needs one-time provisioning and device-bound credentials.
- Physical SUNMI printing, true printer health, offline persistence/sync and gateway remain unimplemented.
- No live Flutter compile or Supabase migration execution performed.
