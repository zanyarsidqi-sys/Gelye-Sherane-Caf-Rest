# Upgrade 1341: direct unpaid-card payment navigation

- Dashboard Standing Cash and Pending Payment cards now open the actual PaymentsManagementPanel (iPhone full-screen, desktop side sheet) rather than a generic static metric detail.
- New optional `initialFocus` prioritizes the relevant real Flutter workflow: active-table guarded cash collection for Standing Cash, or a fail-closed Pending Payment panel.
- Pending Payment collection is intentionally disabled: no complete authorized online/motel settlement and prepaid coverage ledger exists yet. Never collect funds against a cash-only estimate.
- No SQL migration in this upgrade. Existing `gs_standing_cash_collect_cash` is still restricted to eligible active visits and must be deployed and tested before real use.
- Source inspection and archive integrity checks only; Flutter compiler and Supabase runtime tests unavailable in this environment.
