# Upgrade 1194 — Customer and cashier service task connection

- Customer QR requests for `pick_dishes` and `clean_table` already pass through
  `gs_customer_request_employee`, which checks visit token, active table, rate
  limit and duplicate active requests. A trigger now creates one linked task in
  the Kitchen service queue. The customer cannot insert directly into task tables.
- Cashier/authorized Table Orders employees already use `gs_create_service_task`
  in the Service Tasks tab, with Table Orders edit permission. No new cashier
  privileges are granted.
- The `source_call_id` unique index prevents duplicate task creation for a call.
- Staff task history identifies `customer_requested`; anonymous customers have
  a null `requested_by`/event actor, rather than a fabricated employee identity.

## Limitations / next integration

Customer-call status and Kitchen service-task status remain separate. Completing
one does not automatically complete the other. A follow-up must synchronize
status changes transactionally and avoid duplicate completion. Live Supabase
migration and Flutter integration have not been verified.
