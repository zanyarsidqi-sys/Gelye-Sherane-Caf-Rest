-- Upgrade 244: Idempotent immutable discounted-invoice snapshot; NOT payment settlement.
-- Requires complete payment-ledger inventory before production settlement integration.
create table if not exists public.gs_admin_discount_invoice_snapshots (
 id bigint generated always as identity primary key,
 order_id bigint not null references public.gs_orders(id) on delete restrict,
 draft_id bigint not null unique references public.gs_admin_bill_discount_drafts(id) on delete restrict,
 source_total_iqd bigint not null check (source_total_iqd > 0),
 bill_discount_iqd bigint not null check (bill_discount_iqd >= 0),
 amount_due_iqd bigint not null check (amount_due_iqd >= 0),
 item_snapshot jsonb not null,
 approved_by uuid not null references auth.users(id),
 committed_by uuid not null references auth.users(id),
 committed_at timestamptz not null default now(),
 check (amount_due_iqd = source_total_iqd - bill_discount_iqd),
 unique(order_id)
);
alter table public.gs_admin_discount_invoice_snapshots enable row level security;
revoke all on public.gs_admin_discount_invoice_snapshots from public,anon,authenticated;

create or replace function public.gs_commit_admin_discount_invoice_snapshot(p_order_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_order public.gs_orders%rowtype;
 v_draft public.gs_admin_bill_discount_drafts%rowtype;
 v_snapshot public.gs_admin_discount_invoice_snapshots%rowtype;
 v_ready jsonb;
 v_items jsonb;
 v_total bigint;
 v_has_discount boolean;
 v_expected bigint;
begin
 if auth.uid() is null or not exists
  (select 1 from public.gs_cafe_discount_admins where user_id=auth.uid())
 then raise exception 'Admin authorization required'; end if;
 if p_order_id is null or p_order_id <= 0 then raise exception 'Invalid order'; end if;
 -- All writers using parent-order locking serialize with this operation.
 select * into v_order from public.gs_orders where id=p_order_id for update;
 if not found then raise exception 'Order not found'; end if;
 select * into v_snapshot from public.gs_admin_discount_invoice_snapshots where order_id=p_order_id;
 if found then
   return jsonb_build_object('snapshot_id',v_snapshot.id,'order_id',p_order_id,
     'source_total_iqd',v_snapshot.source_total_iqd,
     'bill_discount_iqd',v_snapshot.bill_discount_iqd,
     'amount_due_iqd',v_snapshot.amount_due_iqd,
     'status','existing_immutable_snapshot','payment_settled',false);
 end if;
 v_ready := public.gs_admin_discount_finalization_readiness(p_order_id);
 if v_ready->>'status' <> 'provisional_ready' then
   raise exception 'Invoice snapshot blocked: %',v_ready->>'reason';
 end if;
 select * into v_draft from public.gs_admin_bill_discount_drafts
 where id=(v_ready->>'draft_id')::bigint for update;
 if not found then raise exception 'Approved draft unavailable'; end if;
 select coalesce(sum(line_total_iqd),0)::bigint,
   coalesce(bool_or(discount_per_unit_iqd>0),false),
   coalesce(jsonb_agg(to_jsonb(i) order by i.id),'[]'::jsonb)
 into v_total,v_has_discount,v_items
 from public.gs_order_items i where i.order_id=p_order_id;
 if v_total<=0 or v_total<>v_draft.source_total_iqd then
   raise exception 'Order changed; new approval required';
 end if;
 if v_has_discount and not v_draft.allow_item_discount_stacking then
   raise exception 'Item-level discount stacking not authorized';
 end if;
 v_expected := case when v_draft.discount_type='percent' then
   round(v_total::numeric*v_draft.discount_value/100)::bigint
   else v_draft.discount_value::bigint end;
 v_expected := least(v_total,v_expected);
 if v_expected<>v_draft.bill_discount_iqd or
   v_draft.proposed_total_iqd<>v_total-v_expected then
   raise exception 'Discount draft amount mismatch';
 end if;
 insert into public.gs_admin_discount_invoice_snapshots
 (order_id,draft_id,source_total_iqd,bill_discount_iqd,amount_due_iqd,
  item_snapshot,approved_by,committed_by)
 values (p_order_id,v_draft.id,v_total,v_expected,v_total-v_expected,
  v_items,v_draft.approved_by,auth.uid()) returning * into v_snapshot;
 return jsonb_build_object('snapshot_id',v_snapshot.id,'order_id',p_order_id,
  'source_total_iqd',v_snapshot.source_total_iqd,
  'bill_discount_iqd',v_snapshot.bill_discount_iqd,
  'amount_due_iqd',v_snapshot.amount_due_iqd,
  'status','immutable_snapshot_created','payment_settled',false);
end; $$;
revoke all on function public.gs_commit_admin_discount_invoice_snapshot(bigint) from public,anon;
grant execute on function public.gs_commit_admin_discount_invoice_snapshot(bigint) to authenticated;

-- Snapshot immutability: even privileged direct writes are rejected except migrations
-- explicitly replacing this trigger.
create or replace function public.gs_reject_discount_invoice_snapshot_mutation()
returns trigger language plpgsql set search_path = '' as $$
begin raise exception 'Discount invoice snapshots are immutable'; end; $$;
drop trigger if exists gs_discount_invoice_snapshots_immutable on public.gs_admin_discount_invoice_snapshots;
create trigger gs_discount_invoice_snapshots_immutable before update or delete
on public.gs_admin_discount_invoice_snapshots for each row
execute function public.gs_reject_discount_invoice_snapshot_mutation();
