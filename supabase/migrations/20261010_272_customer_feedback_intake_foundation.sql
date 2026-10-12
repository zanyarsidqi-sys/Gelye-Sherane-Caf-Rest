-- Upgrade 272: customer feedback intake foundation.
-- No anonymous insert or submit RPC is exposed until a cryptographically
-- verified, visit-scoped customer session is available.
create table if not exists public.gs_customer_table_feedback (
 id uuid primary key default gen_random_uuid(),
 visit_id bigint not null,
 table_id bigint not null,
 kind text not null check (kind in ('survey','item_rating','suggestion','new_product')),
 product_id bigint,
 rating integer check (rating between 1 and 5),
 comment text check (comment is null or char_length(comment)<=1000),
 requested_product text check (requested_product is null or char_length(requested_product)<=120),
 status text not null default 'new' check (status in ('new','in_review','approved','done','rejected')),
 created_at timestamptz not null default now(),
 reviewed_by uuid,
 reviewed_at timestamptz,
 constraint gs_feedback_rating_required check (
   (kind in ('survey','item_rating') and rating is not null)
   or (kind in ('suggestion','new_product') and rating is null)
 ),
 constraint gs_feedback_product_required check (
   kind <> 'item_rating' or product_id is not null
 ),
 constraint gs_feedback_new_product_required check (
   kind <> 'new_product' or length(trim(coalesce(requested_product,'')))>0
 )
);
create index if not exists gs_customer_feedback_visit_idx
 on public.gs_customer_table_feedback(visit_id,created_at desc);
alter table public.gs_customer_table_feedback enable row level security;
revoke all on public.gs_customer_table_feedback from public,anon,authenticated;

create or replace function public.gs_staff_customer_feedback_list(p_limit integer default 100)
returns setof jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
   raise exception 'Not authorized to view customer feedback';
 end if;
 return query
 select to_jsonb(f) from public.gs_customer_table_feedback f
 order by f.created_at desc limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.gs_staff_customer_feedback_list(integer) from public,anon;
grant execute on function public.gs_staff_customer_feedback_list(integer) to authenticated;
