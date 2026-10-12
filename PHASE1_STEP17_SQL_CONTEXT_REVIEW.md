# Phase 1 Step 17 — Contextual SQL operation review

Project: Rest. Original SQL unchanged. No database execution.

Reviewed 21 DROP/TRUNCATE/DELETE occurrences from Step 16.

## Classification summary

- conditional_policy_or_trigger_replacement: 4
- function_scoped_delete_review: 6
- requires_manual_review: 9
- temporary_table_only: 2

## Findings

- `20261009_021_cash_payment_ledger.sql:15` — DROP object — **conditional_policy_or_trigger_replacement** — `drop policy if exists gs_cash_payments_read on public.gs_cash_payments;`
- `20261009_029_recipe_ingredient_consumption.sql:37` — DELETE rows — **function_scoped_delete_review** — `delete from public.gs_product_recipes where menu_product_id=p_menu_product_id and ingredient_product_id=p_ingredient_product_id;`
- `20261010_183_counter_draft_item_removal.sql:14` — DELETE rows — **function_scoped_delete_review** — `delete from public.gs_counter_order_request_items`
- `20261010_197_worker_job_capabilities.sql:80` — DROP object — **conditional_policy_or_trigger_replacement** — `drop trigger if exists gs_validate_table_job_assignee_trigger on public.gs_table_service_jobs;`
- `20261010_197_worker_job_capabilities.sql:55` — DELETE rows — **function_scoped_delete_review** — `delete from public.gs_table_worker_capabilities`
- `20261010_199_active_job_capability_guards.sql:71` — DROP object — **conditional_policy_or_trigger_replacement** — `drop trigger if exists gs_guard_active_table_capability_revoke_trg`
- `20261010_199_active_job_capability_guards.sql:49` — DELETE rows — **function_scoped_delete_review** — `delete from public.gs_table_worker_capabilities`
- `20261010_226_pos_device_heartbeat.sql:40` — DROP object — **requires_manual_review** — `drop function if exists public.gs_list_cafe_pos_devices();`
- `20261010_294_event_scope_safety.sql:22` — DROP object — **conditional_policy_or_trigger_replacement** — `drop trigger if exists gs_event_scope_approval_guard_trigger on public.gs_event_reservations;`
- `20261010_294_event_scope_safety.sql:36` — DELETE rows — **function_scoped_delete_review** — `delete from public.gs_event_requested_tables where event_id=e.id;`
- `20261010_294_event_scope_safety.sql:49` — DELETE rows — **function_scoped_delete_review** — `delete from public.gs_event_requested_tables where event_id=e.id;`
- `20261010_357_motel_food_delivery.sql:42` — DROP object — **requires_manual_review** — `drop function if exists public.gs_staff_list_motel_food_requests();`
- `20261010_371_motel_food_invoice_source_reservations.sql:36` — TRUNCATE — **temporary_table_only** — `truncate pg_temp.gs_invoice_sources_371;`
- `20261010_374_motel_food_invoice_register.sql:42` — TRUNCATE — **temporary_table_only** — `truncate pg_temp.gs_invoice_expected_374;`
- `20261010_404_motel_credit_verification_review.sql:28` — DROP object — **requires_manual_review** — `drop function if exists public.gs_staff_list_motel_credit_verifications(uuid);`
- `20261010_539_kitchen_revision_acknowledgement.sql:124` — DROP object — **requires_manual_review** — `drop function if exists public.gs_staff_order_revision_dispatch(bigint);`
- `20261010_541_kitchen_revision_delivery_visibility.sql:3` — DROP object — **requires_manual_review** — `drop function if exists public.gs_staff_order_revision_dispatch(bigint);`
- `20261010_550_kitchen_revision_case_resolution.sql:37` — DROP object — **requires_manual_review** — `drop function if exists public.gs_staff_kitchen_revision_exception_cases(bigint);`
- `20261010_551_kitchen_exception_reopen.sql:51` — DROP object — **requires_manual_review** — `drop function if exists public.gs_staff_kitchen_revision_exception_cases(bigint);`
- `20261011_1179_kitchen_guest_item_instructions.sql:51` — DROP object — **requires_manual_review** — `drop function if exists public.gs_kitchen_order_item_details(bigint);`
- `20261011_1204_replacement_preparation_delivery.sql:106` — DROP object — **requires_manual_review** — `drop function if exists public.gs_kitchen_correction_revision_queue();`

## Safeguards
- `TRUNCATE pg_temp.*` operates on session temporary tables, not permanent application tables, but function context still needs review.
- Conditional DROP POLICY/TRIGGER may be a legitimate replace pattern; verify replacement creation and permissions.
- DELETE inside a function must be reviewed for authorization, predicates, and effects.
- Never run these migrations on production until migration history, rollback, and isolated execution have been verified.