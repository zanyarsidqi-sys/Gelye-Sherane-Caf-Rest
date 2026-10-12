-- Upgrade 1475: run AFTER migrations on staging with psql -v ON_ERROR_STOP=1.
-- Read-only preflight. No production records are modified.
BEGIN READ ONLY;
select to_regclass('public.gs_motel_cafe_order_identity_evidence') is not null as mapping_table_exists,
 to_regclass('public.gs_motel_cafe_identity_approvals') is not null as approval_table_exists,
 to_regprocedure('public.gs_approve_motel_cafe_identity(uuid,text,text)') is not null as approval_rpc_exists;
select count(*) as self_approval_violations from public.gs_motel_cafe_identity_approvals a
join public.gs_motel_cafe_order_identity_evidence m on m.id=a.mapping_id
where a.approved_by=m.verified_by;
select count(*) as approved_mappings from public.gs_motel_cafe_identity_approvals;
ROLLBACK;
