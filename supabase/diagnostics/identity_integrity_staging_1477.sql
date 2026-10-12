-- Run only on an authorized staging database after applying migrations.
-- No writes; confirms function availability and permissions.
begin read only;
select to_regprocedure('public.gs_financial_review_approved_identity_integrity(uuid)') is not null as rpc_exists;
select has_function_privilege('authenticated','public.gs_financial_review_approved_identity_integrity(uuid)','EXECUTE') as staff_execute_granted;
select has_function_privilege('anon','public.gs_financial_review_approved_identity_integrity(uuid)','EXECUTE') as anonymous_execute_granted;
rollback;
