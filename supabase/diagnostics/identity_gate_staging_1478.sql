-- Upgrade 1478: staging preflight; run with psql against a disposable staging DB.
-- Requires existing migrations; this script never changes production data.
BEGIN READ ONLY;
select to_regprocedure('public.gs_financial_review_approved_identity_integrity(uuid)') is not null as identity_review_present;
select to_regprocedure('public.gs_financial_approved_identity_settlement_gate(uuid)') is not null as settlement_gate_present;
select relrowsecurity from pg_class where oid='public.gs_motel_cafe_identity_approvals'::regclass;
select count(*) as mapping_count from public.gs_motel_cafe_order_identity_evidence;
select count(*) as independent_approvals from public.gs_motel_cafe_identity_approvals a join public.gs_motel_cafe_order_identity_evidence m on m.id=a.mapping_id where a.approved_by<>m.verified_by;
ROLLBACK;
-- Authenticated invocation, concurrent writes, settlement and rollback tests
-- require seeded staging identities and must be run separately.
