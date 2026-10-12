-- DRAFT: review and deploy only after PC/Supabase verification.
-- No anonymous public writes: public QR intake requires a separately protected endpoint.
create table if not exists public.gs_guest_feedback (
 id uuid primary key default gen_random_uuid(),
 category text not null check (category in ('Concern','Service request','Suggestion','Complaint','Compliment')),
 message text not null check (char_length(trim(message)) between 1 and 2000),
 customer_name text check (char_length(customer_name) <= 100),
 contact text check (char_length(contact) <= 100),
 location_label text check (char_length(location_label) <= 40),
 rating integer check (rating between 1 and 5),
 urgent boolean not null default false,
 status text not null default 'new' check (status in ('new','assigned','in_progress','resolved','closed')),
 created_by uuid not null default auth.uid(),
 created_at timestamptz not null default now()
);
create table if not exists public.gs_product_recommendations (
 id uuid primary key default gen_random_uuid(),
 type text not null check (type in ('Promote existing product','Suggest new product','Improve existing product')),
 product_name text not null check (char_length(trim(product_name)) between 1 and 150),
 reason text not null check (char_length(trim(reason)) between 1 and 2000),
 status text not null default 'pending' check (status in ('pending','approved','rejected')),
 created_by uuid not null default auth.uid(),
 created_at timestamptz not null default now()
);
alter table public.gs_guest_feedback enable row level security;
alter table public.gs_product_recommendations enable row level security;
revoke all on public.gs_guest_feedback from anon;
revoke all on public.gs_product_recommendations from anon;
grant select, insert on public.gs_guest_feedback to authenticated;
grant select, insert on public.gs_product_recommendations to authenticated;
-- Staff may submit; reading is limited to their own submissions until management policies are reviewed.
create policy gs_feedback_submit_self on public.gs_guest_feedback
 for insert to authenticated with check (created_by = auth.uid());
create policy gs_feedback_read_self on public.gs_guest_feedback
 for select to authenticated using (created_by = auth.uid());
create policy gs_recommend_submit_self on public.gs_product_recommendations
 for insert to authenticated with check (created_by = auth.uid());
create policy gs_recommend_read_self on public.gs_product_recommendations
 for select to authenticated using (created_by = auth.uid());
-- No client UPDATE/DELETE or manager approval policies yet.
