-- Upgrade 278: server-authorized visit feedback submission.
-- A static QR token is never accepted as proof of a visit.
-- Submission requires a staff-issued short-lived visit session.
create or replace function public.gs_customer_submit_visit_feedback(
 p_session_token uuid, p_kind text, p_rating integer default null,
 p_comment text default null, p_requested_product text default null)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare v_session public.gs_customer_visit_sessions%rowtype; v_id uuid;
begin
 -- Lock session to serialize rate checks and avoid simultaneous bypasses.
 select s.* into v_session from public.gs_customer_visit_sessions s
 join public.gs_cafe_tables t on t.id=s.table_id
 join public.gs_table_visits v on v.id=s.visit_id and v.table_id=s.table_id
 where s.session_token=p_session_token and s.revoked_at is null
   and s.expires_at>now() and t.occupied=true and v.status='open'
 for update of s;
 if not found then raise exception 'Customer session expired or invalid'; end if;
 if p_kind not in ('survey','suggestion','new_product') then
   raise exception 'This feedback type is not enabled for submission';
 end if;
 if p_kind='survey' and (p_rating is null or p_rating not between 1 and 5) then
   raise exception 'Rating must be 1 through 5';
 end if;
 if p_kind<>'survey' and p_rating is not null then raise exception 'Unexpected rating'; end if;
 if length(coalesce(p_comment,''))>1000 or length(coalesce(p_requested_product,''))>120 then
   raise exception 'Feedback too long';
 end if;
 if p_kind='suggestion' and length(trim(coalesce(p_comment,'')))=0 then
   raise exception 'Recommendation required';
 end if;
 if p_kind='new_product' and length(trim(coalesce(p_requested_product,'')))=0 then
   raise exception 'Requested product required';
 end if;
 -- Per-visit cap; intentionally conservative to reduce anonymous spam.
 if (select count(*) from public.gs_customer_table_feedback f
     where f.visit_id=v_session.visit_id and f.table_id=v_session.table_id
       and f.created_at>now()-interval '1 hour')>=5 then
   raise exception 'Feedback limit reached for this visit';
 end if;
 insert into public.gs_customer_table_feedback
   (visit_id,table_id,kind,rating,comment,requested_product)
 values (v_session.visit_id,v_session.table_id,p_kind,p_rating,
         nullif(trim(p_comment),''),nullif(trim(p_requested_product),''))
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_customer_submit_visit_feedback(uuid,text,integer,text,text) from public;
grant execute on function public.gs_customer_submit_visit_feedback(uuid,text,integer,text,text) to anon,authenticated;
