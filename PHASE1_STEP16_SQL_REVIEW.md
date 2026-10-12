# Phase 1 Step 16 — SQL safety triage

Project: Rest. Reviewed 17 flagged files. Original SQL was not modified.

## Pattern counts

- DROP object: 13
- TRUNCATE: 2
- DELETE rows: 6
- UPDATE rows: 19
- ALTER TABLE: 22

All matches require context-sensitive review. DROP FUNCTION/POLICY may be intentional idempotent migration maintenance; DELETE/UPDATE may be part of legitimate business workflows. Do not automatically rewrite these statements.

## Flagged files

### 20261009_021_cash_payment_ledger.sql
SHA-256: `f33edafa2cc8901e1716bb48cc98d93b7ec882dad00ad3438114d13f62d446ec`
- Line 15 — DROP object: `s_cash_payments from anon, authenticated; grant select on public.gs_cash_payments to authenticated; drop policy if exists gs_cash_payments_read on public.gs_cash_payments; create policy gs_cash_payments_read on public.gs`
- Line 12 — ALTER TABLE: `ow() ); create index if not exists gs_cash_payments_order_idx on public.gs_cash_payments(order_id); alter table public.gs_cash_payments enable row level security; revoke all on public.gs_cash_payments from anon, authenti`

### 20261009_029_recipe_ingredient_consumption.sql
SHA-256: `0d077fb56db4bef641f68e97dc22ca680bb77b86d9834e317e4125b747f4c995`
- Line 37 — DELETE rows: ` -- A zero quantity removes the ingredient; no negative quantities allowed.  if p_quantity=0 then   delete from public.gs_product_recipes where menu_product_id=p_menu_product_id and ingredient_product_id=p_ingredient_pro`
- Line 75 — UPDATE rows: `n s.product_id=q.stock_product_id   group by q.stock_product_id order by q.stock_product_id  loop   update public.gs_inventory_stock   set quantity=quantity-r.qty,updated_at=now()   where product_id=r.product_id and quan`
- Line 13 — ALTER TABLE: `ry key(menu_product_id,ingredient_product_id),  check (menu_product_id <> ingredient_product_id) ); alter table public.gs_product_recipes enable row level security; revoke all on public.gs_product_recipes from public,ano`

### 20261010_183_counter_draft_item_removal.sql
SHA-256: `47dd85939a43440198eed186f96fe03278167928f2986a7ed161042e16aa4592`
- Line 14 — DELETE rows: `_request.status <> 'pending' then   raise exception 'Only pending requests can be edited'; end if;  delete from public.gs_counter_order_request_items  where id=p_item_id and request_id=p_request_id;  if not found then ra`

### 20261010_197_worker_job_capabilities.sql
SHA-256: `cb3fddfdc44ee3b59362aa2efb0c5848cf01fcb12845047d481f39122af3c34f`
- Line 80 — DROP object: `eption 'Employee is not eligible for job type %',new.kind;   end if;  end if;  return new; end; $$; drop trigger if exists gs_validate_table_job_assignee_trigger on public.gs_table_service_jobs; create trigger gs_validat`
- Line 55 — DELETE rows: `user_id,job_kind,granted_by)   values(p_employee,p_kind,auth.uid()) on conflict do nothing;  else   delete from public.gs_table_worker_capabilities   where employee_user_id=p_employee and job_kind=p_kind;  end if;  inser`
- Line 12 — ALTER TABLE: `ers(id),  granted_at timestamptz not null default now(),  primary key(employee_user_id,job_kind) ); alter table public.gs_table_worker_capabilities enable row level security; revoke all on public.gs_table_worker_capabili`
- Line 35 — ALTER TABLE: `  actor uuid not null references auth.users(id),  happened_at timestamptz not null default now() ); alter table public.gs_table_worker_capability_events enable row level security; revoke all on public.gs_table_worker_cap`

### 20261010_199_active_job_capability_guards.sql
SHA-256: `6a77b8c32e533c416deb8bb9de9710ed2f3f29e4b5b6b49133e51c61ce07c4b1`
- Line 71 — DROP object: `'Active table jobs must be reassigned before capability revocation';  end if;  return old; end; $$; drop trigger if exists gs_guard_active_table_capability_revoke_trg  on public.gs_table_worker_capabilities; create trigg`
- Line 49 — DELETE rows: `oke %: employee has % active job(s). Reassign or complete them first.',p_kind,v_active;   end if;   delete from public.gs_table_worker_capabilities   where employee_user_id=p_employee and job_kind=p_kind;  end if;  inser`

### 20261010_226_pos_device_heartbeat.sql
SHA-256: `cbf4e48e6801343a9eeff734869d9c82b683c39f0fc5f99b091268f5aff6663e`
- Line 40 — DROP object: ` adding derived status. -- Status means last authenticated heartbeat, not print hardware readiness. drop function if exists public.gs_list_cafe_pos_devices(); create function public.gs_list_cafe_pos_devices() returns tab`
- Line 19 — UPDATE rows: `where u.id=p_employee_id  ) then raise exception 'Invalid POS device or employee account'; end if;  update public.gs_cafe_pos_devices  set bound_employee_id=p_employee_id,last_seen_at=null  where id=p_device_id;  if not `
- Line 32 — UPDATE rows: `access('tables','can_view') then   raise exception 'Authenticated table access required';  end if;  update public.gs_cafe_pos_devices set last_seen_at=now()  where bound_employee_id=auth.uid() and enabled=true;  get diag`
- Line 4 — ALTER TABLE: ` account. -- Manual heartbeat test is available in Flutter; periodic device agent is not yet built. alter table public.gs_cafe_pos_devices  add column if not exists bound_employee_id uuid references auth.users(id); creat`

### 20261010_294_event_scope_safety.sql
SHA-256: `423651e45491bc43a63e9637bf21d1d9fe7d1df911e6eda88914d02c8bff8f15`
- Line 22 — DROP object: ` table references are inconsistent' using errcode='23514';    end if;  end if;  return new; end $$; drop trigger if exists gs_event_scope_approval_guard_trigger on public.gs_event_reservations; create trigger gs_event_sc`
- Line 36 — DELETE rows: `(p_table_ids,1),0)<>0 then raise exception 'Whole-venue requests cannot specify tables'; end if;    delete from public.gs_event_requested_tables where event_id=e.id;    update public.gs_event_reservations set requested_t`
- Line 49 — DELETE rows: `s);  if v_seats<e.guest_count then raise exception 'Insufficient combined table capacity'; end if;  delete from public.gs_event_requested_tables where event_id=e.id;  insert into public.gs_event_requested_tables(event_id`
- Line 37 — UPDATE rows: `ot specify tables'; end if;    delete from public.gs_event_requested_tables where event_id=e.id;    update public.gs_event_reservations set requested_table_id=null,updated_at=now() where id=e.id;    return 0;  end if;  v`
- Line 52 — UPDATE rows: `nto public.gs_event_requested_tables(event_id,table_id)  select e.id,x from unnest(p_table_ids) x;  update public.gs_event_reservations set requested_table_id=case when v_count=1 then p_table_ids[1] else null end,  updat`

### 20261010_357_motel_food_delivery.sql
SHA-256: `4526f488b7d3f79cb8919ce55118c60ec9bd507d38136a6118f9f2388a6716d3`
- Line 42 — DROP object: `ated;  -- Extend employee listing with delivery assignment, keeping existing output columns stable. drop function if exists public.gs_staff_list_motel_food_requests(); create function public.gs_staff_list_motel_food_requ`
- Line 20 — UPDATE rows: `yee_id is not null then    raise exception 'Only unassigned ready orders may be claimed'; end if;   update public.gs_motel_guest_food_requests   set delivery_employee_id=auth.uid(),delivery_assigned_at=now() where id=p_r`
- Line 31 — UPDATE rows: `_way' then v_new:='delivered';  else raise exception 'Invalid delivery status transition'; end if;  update public.gs_motel_guest_food_requests  set status=v_new,delivered_at=case when v_new='delivered' then now() else de`
- Line 3 — ALTER TABLE: `then dispatch and complete. -- Assignment is explicit; only assigned employee may advance delivery. alter table public.gs_motel_guest_food_requests  add column if not exists delivery_employee_id uuid references auth.user`

### 20261010_371_motel_food_invoice_source_reservations.sql
SHA-256: `305ba3bdf5bfb4796bd778ce8a0e9fa6c5b644872ec9df8b14f401f9cf3ba291`
- Line 36 — TRUNCATE: `, ledger_id uuid, room_id uuid, amount bigint, review_id uuid, fingerprint text  ) on commit drop;  truncate pg_temp.gs_invoice_sources_371;  insert into pg_temp.gs_invoice_sources_371  select c.source_order_id,c.source_`
- Line 17 — ALTER TABLE: ` must add a separate audited transaction-safe posting step.  check(length(review_fingerprint)>0) ); alter table public.gs_motel_food_invoice_source_reservations enable row level security; revoke all on public.gs_motel_fo`

### 20261010_374_motel_food_invoice_register.sql
SHA-256: `15ed5feb81f60ae8ffb662f8fc50a3eeaeb1bbbcd17c72335907ace1a0335346`
- Line 42 — TRUNCATE: `d uuid,ledger_id uuid,room_id uuid,amount bigint,review_id uuid,fingerprint text)  on commit drop;  truncate pg_temp.gs_invoice_expected_374;  insert into pg_temp.gs_invoice_expected_374  select c.source_order_id,c.sourc`
- Line 20 — ALTER TABLE: `rences public.gs_motel_food_billing_ledger(id),  amount_iqd bigint not null check(amount_iqd>=0) ); alter table public.gs_motel_food_invoice_register enable row level security; alter table public.gs_motel_food_invoice_re`
- Line 21 — ALTER TABLE: `heck(amount_iqd>=0) ); alter table public.gs_motel_food_invoice_register enable row level security; alter table public.gs_motel_food_invoice_register_lines enable row level security; revoke all on public.gs_motel_food_in`

### 20261010_404_motel_credit_verification_review.sql
SHA-256: `0058a8086db8bafeb3b408e6c2d65eeeb46469ce80703fdaceb24f390eb0b464`
- Line 28 — DROP object: `;  -- The return columns changed since Upgrade 403; PostgreSQL requires dropping the old signature. drop function if exists public.gs_staff_list_motel_credit_verifications(uuid); create function public.gs_staff_list_mote`
- Line 19 — UPDATE rows: `;  if q.status <> 'pending' then raise exception 'Only pending requests can be cancelled'; end if;  update public.gs_motel_credit_verification_requests  set status='cancelled', cancelled_by=auth.uid(), cancelled_at=now()`

### 20261010_539_kitchen_revision_acknowledgement.sql
SHA-256: `cd3bf69f844cad79c360a297fdd889375a66bb2bc92061c5239352ab7f64998e`
- Line 124 — DROP object: `object('dispatch_id',p_dispatch_id,'status','acknowledged','already_acknowledged',false); end $$;   drop function if exists public.gs_staff_order_revision_dispatch(bigint); -- Upgrade 268: staff-only revision delivery/pr`
- Line 60 — UPDATE rows: `en   raise exception 'Replacement price changed; request a fresh quote and confirm again'; end if;  update public.gs_order_items set product_id=p_new_product_id,unit_price_iqd=v_new_price  where id=p_order_item_id;  sele`
- Line 116 — UPDATE rows: `ding','sent','claimed','failed') then   raise exception 'Revision is not acknowledgeable'; end if;  update public.gs_order_revision_dispatch set status='acknowledged',acknowledged_at=now()  where id=p_dispatch_id;  inser`
- Line 4 — ALTER TABLE: `nt. Existing outbox rows -- are preserved; acknowledgment is a staff review, NOT proof of printing. alter table public.gs_order_revision_dispatch  drop constraint if exists gs_order_revision_dispatch_destination_type_che`
- Line 6 — ALTER TABLE: `der_revision_dispatch  drop constraint if exists gs_order_revision_dispatch_destination_type_check; alter table public.gs_order_revision_dispatch  add constraint gs_order_revision_dispatch_destination_type_check  check(d`
- Line 92 — ALTER TABLE: `lete restrict,  acknowledged_by uuid not null, acknowledged_at timestamptz not null default now()); alter table public.gs_kitchen_revision_acknowledgement_audit enable row level security; revoke all on public.gs_kitchen_`

### 20261010_541_kitchen_revision_delivery_visibility.sql
SHA-256: `96967747e6239834711825221fc3ebb76c81769288e5212d43cca63b92cc153f`
- Line 3 — DROP object: `lacement revisions. -- Acknowledgment is NOT evidence of physical printing or delivery by a worker. drop function if exists public.gs_staff_order_revision_dispatch(bigint); create function public.gs_staff_order_revision_`

### 20261010_550_kitchen_revision_case_resolution.sql
SHA-256: `20c8f088ac35e2227493dbee25f445309d644cef2519cf53b515b294902031d9`
- Line 37 — DROP object: `(bigint,uuid,text) to authenticated;  -- Add resolution metadata to existing protected history RPC. drop function if exists public.gs_staff_kitchen_revision_exception_cases(bigint); create function public.gs_staff_kitche`
- Line 28 — UPDATE rows: `xception 'Receipt audit inconsistency persists; resolve underlying issue before closure';  end if;  update public.gs_kitchen_revision_exception_cases  set status='closed', closed_by=auth.uid(), closed_at=now(), resolutio`

### 20261010_551_kitchen_exception_reopen.sql
SHA-256: `4405dd3742454b27a29599a1b20cfa99db18d8e4e2ee4dddd755e425687545e9`
- Line 51 — DROP object: `bigint,uuid,text) to authenticated;  -- PostgreSQL return shape changes require DROP before CREATE. drop function if exists public.gs_staff_kitchen_revision_exception_cases(bigint); create function public.gs_staff_kitche`
- Line 3 — ALTER TABLE: `ory and safe re-investigation. -- A reopened investigation is a NEW case linked to the closed case. alter table public.gs_kitchen_revision_exception_cases  add column if not exists reopened_from_case_id uuid references p`

### 20261011_1179_kitchen_guest_item_instructions.sql
SHA-256: `f02fd264e50efe95157428cc7258b25bc4cc19b3b071ae1192381c03d1288036`
- Line 51 — DROP object: ` to authenticated;  -- Replace read-only Kitchen RPC with the same fields plus item identity/notes. drop function if exists public.gs_kitchen_order_item_details(bigint); create function public.gs_kitchen_order_item_detai`
- Line 42 — UPDATE rows: `' then    raise exception 'Item instructions can only be edited before order acceptance';  end if;  update public.gs_order_items  set guest_label=v_guest, preparation_notes=v_notes  where id=p_item_id; end; $$; revoke al`
- Line 3 — ALTER TABLE: `d preparation notes. -- Metadata only: financial quantities/prices and table billing are unchanged. alter table public.gs_order_items   add column if not exists guest_label text,   add column if not exists preparation_no`
- Line 6 — ALTER TABLE: `ems   add column if not exists guest_label text,   add column if not exists preparation_notes text; alter table public.gs_order_items   drop constraint if exists gs_order_item_guest_label_limit; alter table public.gs_ord`
- Line 8 — ALTER TABLE: `ext; alter table public.gs_order_items   drop constraint if exists gs_order_item_guest_label_limit; alter table public.gs_order_items   add constraint gs_order_item_guest_label_limit   check (guest_label is null or     (`
- Line 12 — ALTER TABLE: `l is null or     (char_length(guest_label) between 1 and 80 and guest_label = btrim(guest_label))); alter table public.gs_order_items   drop constraint if exists gs_order_item_notes_limit; alter table public.gs_order_ite`
- Line 14 — ALTER TABLE: `_label))); alter table public.gs_order_items   drop constraint if exists gs_order_item_notes_limit; alter table public.gs_order_items   add constraint gs_order_item_notes_limit   check (preparation_notes is null or     (`

### 20261011_1204_replacement_preparation_delivery.sql
SHA-256: `3343c979c25a469db859493f30bfdffe7ebd84fd74b48bd5ca5583b4acd5025c`
- Line 106 — DROP object: `henticated;  -- Add preparation state for employee workflow without changing existing column order. drop function if exists public.gs_kitchen_correction_revision_queue(); create function public.gs_kitchen_correction_revi`
- Line 41 — UPDATE rows: `otice first'; end if;  if (p_action='accept' and r.preparation_state='awaiting_acceptance') then    update public.gs_cafe_correction_station_revisions set preparation_state='accepted',preparation_accepted_at=transaction_`
- Line 43 — UPDATE rows: `oyee=auth.uid() where id=r.id;  elsif p_action='prepare' and r.preparation_state='accepted' then    update public.gs_cafe_correction_station_revisions set preparation_state='preparing',preparation_started_at=transaction_`
- Line 45 — UPDATE rows: `loyee=auth.uid() where id=r.id;  elsif p_action='ready' and r.preparation_state='preparing' then    update public.gs_cafe_correction_station_revisions set preparation_state='ready',preparation_ready_at=transaction_timest`
- Line 88 — UPDATE rows: `f;    if d.picked_up_at is not null then raise exception 'Cannot reassign after pickup'; end if;    update public.gs_cafe_replacement_delivery_tasks set assigned_to=p_employee_id,assigned_by=auth.uid(),assigned_at=transa`
- Line 90 — UPDATE rows: `on_id=r.id;  elsif p_action='accept' and d.assigned_to=auth.uid() and d.accepted_at is null then    update public.gs_cafe_replacement_delivery_tasks set accepted_at=transaction_timestamp(),updated_at=transaction_timestam`
- Line 92 — UPDATE rows: `ckup' and d.assigned_to=auth.uid() and d.accepted_at is not null and d.picked_up_at is null then    update public.gs_cafe_replacement_delivery_tasks set picked_up_at=transaction_timestamp(),updated_at=transaction_timesta`
- Line 94 — UPDATE rows: `r.id;  elsif p_action='deliver' and d.assigned_to=auth.uid() and d.picked_up_at is not null then    update public.gs_cafe_replacement_delivery_tasks set delivered_at=transaction_timestamp(),updated_at=transaction_timesta`
- Line 3 — ALTER TABLE: `n and delivery queue. -- Financial corrections are never modified by these operational transitions. alter table public.gs_cafe_correction_station_revisions  add column if not exists preparation_state text not null defaul`
- Line 6 — ALTER TABLE: `g_acceptance'  check (preparation_state in ('awaiting_acceptance','accepted','preparing','ready')); alter table public.gs_cafe_correction_station_revisions  add column if not exists preparation_accepted_at timestamptz,  `
- Line 27 — ALTER TABLE: `imestamptz not null default transaction_timestamp(),  assigned_to uuid references auth.users(id) ); alter table public.gs_cafe_replacement_delivery_tasks enable row level security; alter table public.gs_cafe_replacement_`
- Line 28 — ALTER TABLE: ` auth.users(id) ); alter table public.gs_cafe_replacement_delivery_tasks enable row level security; alter table public.gs_cafe_replacement_delivery_events enable row level security; revoke all on public.gs_cafe_replaceme`

## Deployment gates
- Verify statements in SQL execution context, including procedural code and dynamic SQL.
- Test staged migrations in an isolated disposable Supabase environment.
- Reconcile migration history and duplicate versions before any deployment.
- Test RLS, MFA, permissions, and data preservation.
- No production deployment is authorized by this report.