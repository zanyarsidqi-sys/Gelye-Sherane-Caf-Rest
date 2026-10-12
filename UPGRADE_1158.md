# Upgrade 1158 — Visible Kitchen confirmation lock

When an employee opens a Kitchen handover confirmation, all status action buttons are disabled immediately and the selected button shows **Confirming...**. On cancellation, success, or failure, the correct confirmation lock is released with a UI rebuild. Session token guards from Upgrade 1157 remain in place, preventing old dialogs from clearing new employees’ confirmations.

Three source-level regression tests pass. Flutter compilation and live Supabase verification remain deferred.
