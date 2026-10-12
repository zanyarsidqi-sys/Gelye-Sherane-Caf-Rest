# Dashboard Upgrade 109 — Actual guest departure and cleaning controls

Added interactive controls to the existing Flutter Dashboard table-details panel:
- Confirm physical departure, with optional shisha pickup requirement.
- Fetch visit-specific cleaning and shisha tasks through a new permission-checked RPC.
- Mark a visit-specific task completed with an explicit confirmation.
- Refresh tasks and show denied/unavailable states without falsely claiming success.

Calls existing write RPCs from Upgrades 107–108. **No table release or
financial settlement is performed or implied.** The view requires a
server-issued `active_visit_id` or `table_visit_id`; without it, no controls
are rendered. The new migration must be deployed after migrations 107–108.

Validation: ZIP CRC and static source checks. Flutter compilation and live
Supabase migration execution remain pending.
