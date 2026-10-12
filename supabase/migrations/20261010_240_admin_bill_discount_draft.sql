-- Upgrade 240: Admin bill discount approval DRAFT only.
-- No settlement, ledger, order item, or printer mutation: existing payment integrity remains intact.
create table if not exists public.gs_admin_bill_discount_drafts (
 id bigint generated always as identity primary key,
 order_id bigint not null references public.gs_orders(id) on delete restrict,
 discount_type text not null check(discount_type in ('percent','fixed_iqd')),
 discount_value numeric(12,2) not null check(discount_value >= 0),
 allow_item_discount_stacking boolean not null default false,
 source_total_iqd bigint not null check(source_total_iqd >= 0),
 bill_discount_iqd bigint not null check(bill_discount_iqd >= 0),
 proposed_total_iqd bigint not null check(proposed_total_iqd >= 0),
 reason text not null check(length(trim(reason)) between 5 and 500),
 approved_by uuid not null references auth.users(id),
 approved_at timestamptz not null default now(),
 status text not null default 'draft' check(status='draft'),
 check(proposed_total_iqd = source_total_iqd - bill_discount_iqd)
);
alter table public.gs_admin_bill_discount_drafts enable row level security;
revoke all on public.gs_admin_bill_discount_drafts from public,anon,authenticated;
create or replace function public.gs_preview_admin_bill_discount(
 p_order_id bigint,p_discount_type text,p_discount_value numeric,
 p_allow_item_discount_stacking boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_total bigint; v_discount bigint; v_has_item_discounts boolean;
begin
 if auth.uid() is null or not exists(select 1 from public.gs_cafe_discount_admins where user_id=auth.uid())
 then raise exception 'Admin authorization required'; end if;
 if p_order_id is null or p_order_id<=0 or p_discount_type not in ('percent','fixed_iqd')
  or p_discount_value is null or p_discount_value<0
  or (p_discount_type='percent' and p_discount_value>100)
  or (p_discount_type='fixed_iqd' and (p_discount_value<>trunc(p_discount_value) or p_discount_value>1000000000))
  or p_allow_item_discount_stacking is null
 then raise exception 'Invalid bill discount'; end if;
 if not exists(select 1 from public.gs_orders where id=p_order_id and status<>'cancelled')
 then raise exception 'Order not found or cancelled'; end if;
 select coalesce(sum(line_total_iqd),0)::bigint,
   coalesce(bool_or(discount_per_unit_iqd>0),false)
 into v_total,v_has_item_discounts from public.gs_order_items where order_id=p_order_id;
 if v_total<=0 then raise exception 'Order has no billable items'; end if;
 if v_has_item_discounts and not p_allow_item_discount_stacking
 then raise exception 'Item discounts already exist: explicitly authorize stacking'; end if;
 -- Fail closed for recorded cash receipts or finance settlement attestations.
 if exists(select 1 from public.gs_cash_payments where order_id=p_order_id)
 or exists(select 1 from public.gs_cash_only_settlement_attestations where order_id=p_order_id)
 then raise exception 'Order has cash payment or settlement records; bill discount blocked'; end if;
 v_discount := case when p_discount_type='percent' then
  round(v_total::numeric*p_discount_value/100)::bigint
  else p_discount_value::bigint end;
 v_discount := least(v_total,v_discount);
 return jsonb_build_object('order_id',p_order_id,'current_total_iqd',v_total,
  'bill_discount_iqd',v_discount,'proposed_total_iqd',v_total-v_discount,
  'item_discounts_present',v_has_item_discounts,'status','preview_only');
end; $$;
revoke all on function public.gs_preview_admin_bill_discount(bigint,text,numeric,boolean) from public,anon;
grant execute on function public.gs_preview_admin_bill_discount(bigint,text,numeric,boolean) to authenticated;
create or replace function public.gs_approve_admin_bill_discount_draft(
 p_order_id bigint,p_discount_type text,p_discount_value numeric,
 p_allow_item_discount_stacking boolean,p_reason text)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_preview jsonb; v_id bigint;
begin
 if p_reason is null or length(trim(p_reason)) not between 5 and 500
 then raise exception 'Approval reason must be 5–500 characters'; end if;
 -- Lock the order against concurrent order changes while calculating and recording draft.
 perform 1 from public.gs_orders where id=p_order_id for update;
 if not found then raise exception 'Order not found'; end if;
 v_preview := public.gs_preview_admin_bill_discount(p_order_id,p_discount_type,
   p_discount_value,p_allow_item_discount_stacking);
 insert into public.gs_admin_bill_discount_drafts(order_id,discount_type,discount_value,
  allow_item_discount_stacking,source_total_iqd,bill_discount_iqd,proposed_total_iqd,reason,approved_by)
 values(p_order_id,p_discount_type,p_discount_value,p_allow_item_discount_stacking,
  (v_preview->>'current_total_iqd')::bigint,(v_preview->>'bill_discount_iqd')::bigint,
  (v_preview->>'proposed_total_iqd')::bigint,trim(p_reason),auth.uid()) returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_approve_admin_bill_discount_draft(bigint,text,numeric,boolean,text) from public,anon;
grant execute on function public.gs_approve_admin_bill_discount_draft(bigint,text,numeric,boolean,text) to authenticated;
