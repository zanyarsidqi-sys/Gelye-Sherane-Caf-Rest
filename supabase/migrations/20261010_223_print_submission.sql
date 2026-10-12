-- Upgrade 223: authenticated, validated queue submission; no physical printing.
-- Requests are metadata-only until a secure renderer and gateway are deployed.
create or replace function public.gs_submit_cafe_print_job(
 p_printer_id bigint, p_document_kind text, p_copies integer)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Table view permission required';
 end if;
 if p_document_kind is null or p_document_kind not in
  ('receipt','kitchen_ticket','shisha_ticket','daily_report','other') then
  raise exception 'Unsupported document type';
 end if;
 if p_copies is null or p_copies not between 1 and 20 then
  raise exception 'Copies must be between 1 and 20';
 end if;
 if not exists (select 1 from public.gs_cafe_printers
    where id=p_printer_id and is_enabled) then
  raise exception 'Printer is unavailable or disabled';
 end if;
 -- No raw document content is accepted from the client. No remote printer
 -- transport is exposed. Queue state is not proof of printing.
 insert into public.gs_cafe_print_jobs(
   printer_id,document_kind,copies,idempotency_key,requested_by)
 values(p_printer_id,p_document_kind,p_copies,gen_random_uuid(),auth.uid())
 returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_submit_cafe_print_job(bigint,text,integer) from public,anon;
grant execute on function public.gs_submit_cafe_print_job(bigint,text,integer) to authenticated;
