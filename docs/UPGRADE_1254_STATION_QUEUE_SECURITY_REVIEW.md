# Upgrade 1254 — Station-scoped Kitchen queues and revision acknowledgements

## Findings and corrections

- The legacy `gs_kitchen_station_ticket_queue` listed tickets across stations to anyone with broad Kitchen view permission. It now requires AAL2 MFA and active station assignment or explicit station-management authorization per row.
- The legacy `gs_kitchen_correction_revision_queue` similarly listed all correction notices. It now restricts rows by station and requires AAL2 MFA.
- The legacy `gs_ack_correction_station_revision` allowed Kitchen editors to acknowledge a revision from another station by supplying its ID. It now locks the row, validates station membership or station-management authorization, and requires AAL2 MFA before updating.
- Existing RPC signatures and response columns are preserved. No invoice/payment rows are changed. Station management remains within Kitchen.

## Caveats / remaining work

- Source-only change: no Flutter compilation, live Supabase migration, RLS or printer verification was performed.
- `gs_1246_can_manage_station` must be reviewed and verified in staging with denied and allowed employee roles.
- Original/revision device print claims and other legacy queue functions need separate exhaustive security audit. In particular, any Edge Function that holds `service_role` credentials must verify caller identity and station session server-side.
- MFA changes may require existing station employees to reauthenticate; test UX before deployment.
- Regression scenarios: station A user sees A only; station B hidden; revoked employee denied; manager authorized only for delegated station; cross-station revision ACK denied; no MFA denied; repeated ACK idempotent; audit event recorded only for a real transition.
