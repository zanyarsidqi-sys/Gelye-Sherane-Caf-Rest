-- Upgrade 1198: auditable wrong/waste item corrections, first stage.
-- CAUTION: Legacy billing queries sum line_total_iqd without adjustment.
-- Do not deploy this migration as a complete invoice correction solution.
create table if not exists public.gs_order_item_corrections (
 id bigint generated always as identity primary key,
 item_id bigint not null references public.gs_order_items(id) on delete restrict,
 order_id bigint not null references public.gs_orders(id) on delete restrict,
 reason text not null check(reason in ('wrong_order','waste','incorrect_preparation')),
 details text not null check(length(btrim(details)) between 5 and 500),
 requested_quantity integer not null check(requested_quantity > 0),
 requested_by uuid not null references auth.users(id),
 requested_at timestamptz not null default now(),
 decision text not null default 'pending' check(decision in ('pending','approved','rejected')),
 decided_by uuid references auth.users(id),
 decided_at timestamptz,
 replacement_product_id bigint references public.gs_menu_products(id),
 replacement_item_id bigint references public.gs_order_items(id),
 check ((decision='pending' and decided_by is null and decided_at is null)
    or (decision<>'pending' and decided_by is not null and decided_at is not null))
);
create unique index if not exists gs_one_pending_item_correction
 on public.gs_order_item_corrections(item_id) where decision='pending';
create index if not exists gs_order_item_corrections_order
 on public.gs_order_item_corrections(order_id, requested_at desc);
alter table public.gs_order_item_corrections enable row level security;
revoke all on public.gs_order_item_corrections from public,anon,authenticated;

create or replace function public.gs_request_order_item_correction(
 p_item_id bigint, p_quantity integer, p_reason text, p_details text,
 p_replacement_product_id bigint default null
) returns bigint language plpgsql security definer set search_path='' as $$
declare v_item record; v_id bigint; v_section text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select i.id, i.order_id, i.quantity, o.status, o.is_motel
 into v_item from public.gs_order_items i
 join public.gs_orders o on o.id=i.order_id
 where i.id=p_item_id for update of o,i;
 if not found then raise exception 'Item not found'; end if;
 v_section := case when v_item.is_motel then 'motel_orders' else 'table_orders' end;
 if not public.gs_can_access(v_section,'can_edit') then
   raise exception 'Not authorized to request correction'; end if;
 if v_item.status in ('served','cancelled') then
   raise exception 'Settled or terminal orders require a separate refund workflow'; end if;
 if p_quantity is null or p_quantity < 1 or p_quantity > v_item.quantity
 or p_reason not in ('wrong_order','waste','incorrect_preparation')
 or length(btrim(coalesce(p_details,''))) not between 5 and 500 then
   raise exception 'Invalid correction request'; end if;
 if p_replacement_product_id is not null and not exists
 (select 1 from public.gs_menu_products where id=p_replacement_product_id and is_active) then
   raise exception 'Replacement product unavailable'; end if;
 insert into public.gs_order_item_corrections
 (item_id,order_id,reason,details,requested_quantity,requested_by,replacement_product_id)
 values(p_item_id,v_item.order_id,p_reason,btrim(p_details),p_quantity,auth.uid(),p_replacement_product_id)
 returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_request_order_item_correction(bigint,integer,text,text,bigint) from public,anon;
grant execute on function public.gs_request_order_item_correction(bigint,integer,text,text,bigint) to authenticated;

-- Decision deliberately records approval without mutating financial records.
-- This prevents a misleading partial correction while older invoice and payment
-- paths still sum all order-item line totals.
create or replace function public.gs_decide_order_item_correction(
 p_correction_id bigint, p_approve boolean
) returns void language plpgsql security definer set search_path='' as $$
declare v record;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit')
 then raise exception 'Manager authorization required'; end if;
 select c.id,c.decision,o.status into v
 from public.gs_order_item_corrections c join public.gs_orders o on o.id=c.order_id
 where c.id=p_correction_id for update of c,o;
 if not found then raise exception 'Correction not found'; end if;
 if v.decision <> 'pending' then raise exception 'Correction already decided'; end if;
 if v.status in ('served','cancelled') then
   raise exception 'Terminal order correction requires a refund workflow'; end if;
 update public.gs_order_item_corrections
 set decision=case when p_approve then 'approved' else 'rejected' end,
     decided_by=auth.uid(),decided_at=transaction_timestamp()
 where id=p_correction_id;
end; $$;
revoke all on function public.gs_decide_order_item_correction(bigint,boolean) from public,anon;
grant execute on function public.gs_decide_order_item_correction(bigint,boolean) to authenticated;

create or replace function public.gs_list_order_item_corrections(p_order_id bigint)
returns table(correction_id bigint,item_id bigint,reason text,details text,
 requested_quantity integer,decision text,requested_at timestamptz,decided_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_view')
 or public.gs_can_access('kitchen','can_view')) then
 raise exception 'Not authorized to view corrections'; end if;
 return query select c.id,c.item_id,c.reason,c.details,c.requested_quantity,
 c.decision,c.requested_at,c.decided_at from public.gs_order_item_corrections c
 where c.order_id=p_order_id order by c.requested_at desc;
end; $$;
revoke all on function public.gs_list_order_item_corrections(bigint) from public,anon;
grant execute on function public.gs_list_order_item_corrections(bigint) to authenticated;
