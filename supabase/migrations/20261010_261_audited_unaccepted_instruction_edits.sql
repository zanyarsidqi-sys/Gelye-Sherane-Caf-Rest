-- Upgrade 261: audited, concurrency-safe pre-acceptance instruction edits.
-- This intentionally does not permit unsafe quantity/product edits after kitchen dispatch.
create table if not exists public.gs_order_item_instruction_edit_audit (
 id bigint generated always as identity primary key,
 order_item_id bigint not null references public.gs_order_items(id),
 order_id bigint not null references public.gs_orders(id),
 actor uuid not null references auth.users(id),
 previous_instructions text,
 new_instructions text,
 changed_at timestamptz not null default now()
);
create index if not exists gs_instruction_edit_audit_item_idx
 on public.gs_order_item_instruction_edit_audit(order_item_id,changed_at desc);
alter table public.gs_order_item_instruction_edit_audit enable row level security;
revoke all on public.gs_order_item_instruction_edit_audit from public,anon,authenticated;

-- Caller supplies the value last displayed to avoid silently overwriting another editor.
create or replace function public.gs_edit_unaccepted_order_item_instructions(
 p_order_item_id bigint, p_expected_instructions text, p_new_instructions text)
returns text language plpgsql volatile security definer set search_path='' as $$
declare v_order_id bigint; v_old text; v_new text; v_status text;
 v_fulfillment text; v_visit_status text;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Table order editing permission required';
 end if;
 if p_order_item_id is null or p_order_item_id <= 0 then
  raise exception 'Invalid order item'; end if;
 v_new:=nullif(btrim(p_new_instructions),'');
 if v_new is not null and length(v_new)>500 then
  raise exception 'Instructions must be at most 500 characters'; end if;
 -- Lock order then line, matching the locked-invoice order-first discipline.
 select i.order_id into v_order_id from public.gs_order_items i
 where i.id=p_order_item_id;
 if not found then raise exception 'Order item not found'; end if;
 perform 1 from public.gs_orders where id=v_order_id for update;
 select o.status, v.status into v_status,v_visit_status
 from public.gs_orders o
 left join public.gs_table_visits v on v.id=o.table_visit_id
 where o.id=v_order_id and o.is_motel=false;
 if not found or v_status is distinct from 'new' or v_visit_status is distinct from 'open' then
  raise exception 'Order or table visit is no longer editable'; end if;
 select i.preparation_instructions into v_old from public.gs_order_items i
 where i.id=p_order_item_id and i.order_id=v_order_id for update;
 if not found then raise exception 'Order item changed; refresh'; end if;
 if v_old is distinct from nullif(btrim(p_expected_instructions),'') then
  raise exception 'Instructions changed; refresh before editing'; end if;
 select coalesce(f.status,'not_accepted') into v_fulfillment
 from public.gs_order_items i
 left join public.gs_table_item_fulfillment f on f.order_item_id=i.id
 where i.id=p_order_item_id;
 if v_fulfillment <> 'not_accepted' then
  raise exception 'Item accepted by preparation station; use supervised revision workflow'; end if;
 if exists(select 1 from public.gs_cafe_order_station_ticket_items
           where order_item_id=p_order_item_id) then
  raise exception 'Preparation ticket exists; item changes require station revision'; end if;
 if exists(select 1 from public.gs_admin_discount_invoice_snapshots
           where order_id=v_order_id) then
  raise exception 'Invoice locked; correction workflow required'; end if;
 if v_old is distinct from v_new then
  update public.gs_order_items set preparation_instructions=v_new where id=p_order_item_id;
  insert into public.gs_order_item_instruction_edit_audit
   (order_item_id,order_id,actor,previous_instructions,new_instructions)
  values(p_order_item_id,v_order_id,auth.uid(),v_old,v_new);
 end if;
 return coalesce(v_new,'');
end $$;
revoke all on function public.gs_edit_unaccepted_order_item_instructions(bigint,text,text)
 from public,anon;
grant execute on function public.gs_edit_unaccepted_order_item_instructions(bigint,text,text)
 to authenticated;
