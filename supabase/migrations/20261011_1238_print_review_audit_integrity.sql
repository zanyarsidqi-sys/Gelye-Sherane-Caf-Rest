-- Upgrade 1238: audit records cannot be silently changed or deleted.
-- Review decisions are final; supervisors must create a separate incident record
-- for later disagreements instead of rewriting the original decision.
create or replace function public.gs_1238_print_review_audit_immutable()
returns trigger language plpgsql set search_path='' as $$
begin
  raise exception 'Print review audit history is immutable';
end $$;
drop trigger if exists gs_1238_print_review_audit_immutable
  on public.gs_cafe_print_review_audit_1237;
create trigger gs_1238_print_review_audit_immutable
before update or delete on public.gs_cafe_print_review_audit_1237
for each row execute function public.gs_1238_print_review_audit_immutable();
revoke all on function public.gs_1238_print_review_audit_immutable() from public,anon,authenticated;
