# Dashboard Upgrade 33 — employee cloud layout preferences

- Added authenticated Supabase RPC draft for per-employee layout preferences.
- Dashboard loads local preferences immediately and then attempts cloud load.
- Changes are saved locally first; cloud save is best-effort with no fake success.
- Cloud payload includes focus mode, card order, individual colors, sizes, visibility.
- Backend chooses user ID via auth.uid() and checks Dashboard access.
- Migration 038 is a DRAFT; not deployed, compiled, or tested.
- Known limitations: cloud-vs-local conflict uses last-write-wins; no automatic retry of offline edits; separate device layouts not yet implemented; sync message state not yet shown in UI.
