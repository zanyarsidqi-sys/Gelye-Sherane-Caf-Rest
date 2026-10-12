-- Upgrade 385: reconcile posted finance invoice source lines against the original food register.
-- Read-only: never creates payments, invoices or credit transactions.
create or replace function public.gs_staff_check_motel_food_finance_invoice(p_finance_invoice_id uuid)
returns table(finance_invoice_id uuid,check_status text,issue_count integer,expected_count integer,actual_count bigint,expected_iqd bigint,actual_iqd numeric,details text)
language plpgsql security definer set search_path = '' as $$
declare v public.gs_motel_food_finance_invoices%rowtype;
 v_actual_count bigint;v_actual_iqd numeric;v_issues integer:=0;v_details text:='';v_source_count bigint;v_source_total numeric;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and finance viewing permissions required';
 end if;
 select * into v from public.gs_motel_food_finance_invoices f where f.id=p_finance_invoice_id;
 if not found then raise exception 'Finance invoice not found'; end if;
 select count(*),coalesce(sum(l.amount_iqd),0) into v_actual_count,v_actual_iqd
 from public.gs_motel_food_finance_invoice_lines l where l.finance_invoice_id=v.id;
 select count(*),coalesce(sum(r.amount_iqd),0) into v_source_count,v_source_total
 from public.gs_motel_food_invoice_register_lines r where r.invoice_id=v.food_invoice_id;
 if v_actual_count<>v.source_count or v_actual_iqd<>v.total_iqd then
  v_issues:=v_issues+1;v_details:=v_details||'Finance line count or total differs; ';
 end if;
 if v_source_count<>v.source_count or v_source_total<>v.total_iqd then
  v_issues:=v_issues+1;v_details:=v_details||'Source register changed; ';
 end if;
 if exists(select 1 from public.gs_motel_food_invoice_register_lines r
   left join public.gs_motel_food_finance_invoice_lines l
   on l.source_register_line_id=r.id and l.finance_invoice_id=v.id
   where r.invoice_id=v.food_invoice_id and
   (l.id is null or l.source_order_id is distinct from r.source_order_id
    or l.amount_iqd is distinct from r.amount_iqd)) then
  v_issues:=v_issues+1;v_details:=v_details||'Missing or mismatched source lines; ';
 end if;
 if exists(select 1 from public.gs_motel_food_finance_invoice_lines l
   left join public.gs_motel_food_invoice_register_lines r on r.id=l.source_register_line_id
   where l.finance_invoice_id=v.id and (r.id is null or r.invoice_id is distinct from v.food_invoice_id)) then
  v_issues:=v_issues+1;v_details:=v_details||'Unexpected finance source line; ';
 end if;
 if exists(select 1 from public.gs_motel_food_finance_invoice_lines l
   join public.gs_motel_guest_food_requests o on o.id=l.source_order_id
   where l.finance_invoice_id=v.id and
   (o.guest_session_id is distinct from v.guest_session_id or o.room_id is distinct from v.room_id
    or o.status is distinct from 'delivered' or o.total_iqd is distinct from l.amount_iqd)) then
  v_issues:=v_issues+1;v_details:=v_details||'Guest, room, delivery or amount mismatch; ';
 end if;
 return query select v.id,case when v_issues=0 then 'matched' else 'requires_review' end::text,
 v_issues,v.source_count,v_actual_count,v.total_iqd,v_actual_iqd,
 case when v_issues=0 then 'All source checks passed; payment remains separate.' else v_details end;
end; $$;
revoke all on function public.gs_staff_check_motel_food_finance_invoice(uuid) from public,anon;
grant execute on function public.gs_staff_check_motel_food_finance_invoice(uuid) to authenticated;
