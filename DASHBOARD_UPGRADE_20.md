# Dashboard Coding Upgrade 20

- Wired the existing read-only payment confirmation queue into the Dashboard.
- The card is only shown when both `dashboard` and `payments_management` appear in the authorized section set; the RPC must separately enforce backend permissions.
- iPhone/narrow windows open a full screen; wide Windows layouts open a right-side panel.
- The queue does not approve, reject, debit, or mark any payment paid. The screenshot is evidence only, never confirmation of funds.
- No fabricated queue counts are shown.
- Pending: secure server-side receiver approvals, verified funds, screenshot storage and access, audit, idempotency, transaction-level records, and end-to-end testing.
- Flutter compilation and live Supabase verification deferred at user request.
