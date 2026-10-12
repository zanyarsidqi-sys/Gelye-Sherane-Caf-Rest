# Upgrade 1257 — Kitchen print-review session safety

## Source changes
- Supervisor review panel clears station-scoped records immediately on employee identity change.
- In-flight refresh errors from an earlier identity cannot overwrite the next employee's state.
- A pending review submission suppresses overlapping refreshes and duplicate submissions.
- Success/failure notifications and refresh after submission are bound to the same employee and queue generation.

## Reviewed existing source
- Live Kitchen order cards load customer/station summaries from `gs_kitchen_order_items` with a generation and user identity guard.
- Station ticket detail panel calls `gs_kitchen_station_ticket_details`; authorization remains dependent on the packaged database migrations.
- Station print review uses `gs_1237_review_print_ticket`; server-side station permission and lease enforcement are mandatory.

## Outstanding / deferred
- A submission already sent before logout cannot be cancelled client-side. Server must authenticate and authorize each request; review audit records remain authoritative.
- Station print-review UI still needs real-user testing for sign-out/sign-in, multi-station supervisor permissions, expired leases and network failure.
- Flutter compilation, Supabase migration execution and physical printer tests explicitly deferred.
- POS/A4 PDF output and finalized invoice integration remain incomplete.
