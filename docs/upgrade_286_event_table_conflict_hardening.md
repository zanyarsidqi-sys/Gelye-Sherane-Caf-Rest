# Upgrade 286 — Event/table conflict hardening

- Extended the existing table availability RPC to reject time overlaps with approved café events.
- Serialized Admin event approval with staff reservation confirmation using the same transaction advisory lock.
- Enforced table seat capacity on event approval.
- Retained the existing Admin authorization and review audit trail.

## Remaining limitations
- Other legacy reservation confirmation/transfer RPCs must be audited for the same locking and event checks.
- Event bookings without a specific table require venue/area-wide capacity rules.
- No live Supabase migration execution or Flutter compilation was performed.
- Public anonymous booking endpoints still require rate limiting and CAPTCHA.
