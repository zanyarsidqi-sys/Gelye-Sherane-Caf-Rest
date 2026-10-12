# Upgrade 198 — Manager employee job permission controls

- Added manager dialog in `lib/sections/tables.dart` with searchable active employee list, responsibility checkboxes, save-per-change behavior, error feedback and refresh.
- Added permission-protected RPCs to list active employees and current capability grants. Existing audited `gs_set_table_worker_capability` remains the sole write path.
- Initial dialog requires tapping **Load / Refresh employees**; does not automatically fetch on opening.
- Backend checks use `employees.can_edit` for both listing and writing. No direct table grants.
- Estimated Tables completion: 77%. Not compiled or deployed against live Supabase.
