-- Section 03: customer table-order requests require a staff-issued active visit.
-- A request is not a billable order or kitchen order until an authorized staff
-- member accepts it. Staff acceptance uses the existing server-priced cart RPC.

create table if not exists public.gs_customer_table_order_requests (
  id uuid primary key default gen_random_uuid(),
  table_id bigint not null references public.gs_cafe_tables(id) on delete restrict,
  visit_id bigint not null references public.gs_table_visits(id) on delete restrict,
  visit_session_token uuid not null
    references public.gs_customer_visit_sessions(session_token) on delete restrict,
  idempotency_key uuid not null,
  items jsonb not null check (jsonb_typeof(items) = 'array'),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected')),
  order_id bigint references public.gs_orders(id) on delete restrict,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid,
  rejection_reason text,
  unique (visit_id, idempotency_key),
  check (status <> 'accepted' or (order_id is not null and reviewed_at is not null
    and reviewed_by is not null)),
  check (status <> 'rejected' or (rejection_reason is not null and reviewed_at is not null
    and reviewed_by is not null))
);

create index if not exists gs_customer_table_order_requests_pending_idx
  on public.gs_customer_table_order_requests(submitted_at, id)
  where status = 'pending';
create index if not exists gs_customer_table_order_requests_session_idx
  on public.gs_customer_table_order_requests(visit_session_token, submitted_at desc);

alter table public.gs_customer_table_order_requests enable row level security;
revoke all on public.gs_customer_table_order_requests from public, anon, authenticated;

create table if not exists public.gs_customer_table_order_request_events (
  id bigint generated always as identity primary key,
  request_id uuid not null
    references public.gs_customer_table_order_requests(id) on delete restrict,
  event_type text not null check (event_type in ('submitted', 'accepted', 'rejected')),
  actor_user_id uuid,
  order_id bigint,
  reason text,
  occurred_at timestamptz not null default now()
);
alter table public.gs_customer_table_order_request_events enable row level security;
revoke all on public.gs_customer_table_order_request_events from public, anon, authenticated;

create or replace function public.gs_guard_customer_table_order_event()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  raise exception 'Customer table-order request history is immutable';
end;
$$;
revoke all on function public.gs_guard_customer_table_order_event() from public, anon, authenticated;
drop trigger if exists gs_customer_table_order_event_immutable
  on public.gs_customer_table_order_request_events;
create trigger gs_customer_table_order_event_immutable
  before update or delete on public.gs_customer_table_order_request_events
  for each row execute function public.gs_guard_customer_table_order_event();

create or replace function public.gs_public_submit_table_order_request(
  p_table_qr_token uuid,
  p_session_token uuid,
  p_idempotency_key uuid,
  p_items jsonb
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_session public.gs_customer_visit_sessions%rowtype;
  v_line jsonb;
  v_product_id bigint;
  v_quantity integer;
  v_instructions text;
  v_seen bigint[] := '{}'::bigint[];
  v_normalized jsonb := '[]'::jsonb;
  v_request_id uuid;
  v_existing_items jsonb;
  v_recent_count integer;
begin
  if p_table_qr_token is null or p_session_token is null or p_idempotency_key is null then
    raise exception 'Table, visit, and retry references are required';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) not between 1 and 100 then
    raise exception 'Cart must contain 1–100 items';
  end if;

  select s.* into v_session
  from public.gs_customer_visit_sessions s
  join public.gs_table_qr_tokens q
    on q.table_id = s.table_id and q.token = p_table_qr_token
  join public.gs_cafe_tables t on t.id = s.table_id and t.occupied = true
  join public.gs_table_visits v
    on v.id = s.visit_id and v.table_id = s.table_id and v.status = 'open'
  where s.session_token = p_session_token
    and s.revoked_at is null and s.expires_at > now()
  for update of s;
  if not found then raise exception 'Verified active table visit required'; end if;
  if not exists (select 1 from public.cafe_website_settings s
                 where s.id = 1 and s.menu_enabled = true) then
    raise exception 'Customer menu is unavailable';
  end if;

  for v_line in select value from jsonb_array_elements(p_items) as x(value) loop
    if jsonb_typeof(v_line) <> 'object'
       or jsonb_typeof(v_line->'product_id') <> 'number'
       or jsonb_typeof(v_line->'quantity') <> 'number'
       or (v_line ? 'instructions' and jsonb_typeof(v_line->'instructions') not in ('string', 'null')) then
      raise exception 'Invalid cart item';
    end if;
    begin
      v_product_id := (v_line->>'product_id')::bigint;
      v_quantity := (v_line->>'quantity')::integer;
    exception when invalid_text_representation or numeric_value_out_of_range then
      raise exception 'Invalid product or quantity';
    end;
    v_instructions := nullif(btrim(coalesce(v_line->>'instructions', '')), '');
    if v_product_id <= 0 or v_quantity not between 1 and 999
       or char_length(v_instructions) > 500 then
      raise exception 'Invalid product, quantity, or instructions';
    end if;
    if v_product_id = any(v_seen) then raise exception 'Duplicate product in cart'; end if;
    v_seen := array_append(v_seen, v_product_id);
    v_normalized := v_normalized || jsonb_build_array(jsonb_build_object(
      'product_id', v_product_id,
      'quantity', v_quantity,
      'instructions', v_instructions
    ));
  end loop;

  select r.id, r.items into v_request_id, v_existing_items
  from public.gs_customer_table_order_requests r
  where r.visit_id = v_session.visit_id and r.idempotency_key = p_idempotency_key;
  if found then
    if v_existing_items is distinct from v_normalized then
      raise exception 'Retry reference was already used for a different cart';
    end if;
    return v_request_id;
  end if;

  for v_line in select value from jsonb_array_elements(v_normalized) as x(value) loop
    v_product_id := (v_line->>'product_id')::bigint;
    if not exists (
      select 1 from public.gs_public_table_menu(p_table_qr_token) m
      where m.product_id = v_product_id
    ) then raise exception 'A requested menu item is unavailable'; end if;
  end loop;

  select count(*) into v_recent_count
  from public.gs_customer_table_order_requests r
  where r.visit_session_token = p_session_token
    and r.submitted_at > now() - interval '1 hour';
  if v_recent_count >= 20 then raise exception 'Too many requests for this visit'; end if;

  insert into public.gs_customer_table_order_requests(
    table_id, visit_id, visit_session_token, idempotency_key, items
  ) values (
    v_session.table_id, v_session.visit_id, p_session_token, p_idempotency_key, v_normalized
  )
  on conflict (visit_id, idempotency_key) do nothing
  returning id into v_request_id;

  if v_request_id is null then
    select r.id, r.items into v_request_id, v_existing_items
    from public.gs_customer_table_order_requests r
    where r.visit_id = v_session.visit_id and r.idempotency_key = p_idempotency_key;
    if v_existing_items is distinct from v_normalized then
      raise exception 'Retry reference was already used for a different cart';
    end if;
    return v_request_id;
  end if;

  insert into public.gs_customer_table_order_request_events(request_id, event_type)
  values (v_request_id, 'submitted');
  return v_request_id;
end;
$$;
revoke all on function public.gs_public_submit_table_order_request(uuid, uuid, uuid, jsonb) from public;
grant execute on function public.gs_public_submit_table_order_request(uuid, uuid, uuid, jsonb)
  to anon, authenticated;

create or replace function public.gs_customer_table_order_request_status(
  p_session_token uuid,
  p_request_id uuid
) returns table(request_id uuid, status text, order_id bigint,
                rejection_reason text, submitted_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.gs_customer_visit_sessions s
    join public.gs_cafe_tables t on t.id = s.table_id and t.occupied = true
    join public.gs_table_visits v
      on v.id = s.visit_id and v.table_id = s.table_id and v.status = 'open'
    where s.session_token = p_session_token
      and s.revoked_at is null and s.expires_at > now()
  ) then raise exception 'Verified active table visit required'; end if;

  return query
  select r.id, r.status, r.order_id, r.rejection_reason, r.submitted_at
  from public.gs_customer_table_order_requests r
  join public.gs_customer_visit_sessions s
    on s.session_token = r.visit_session_token
   and s.session_token = p_session_token
   and s.visit_id = r.visit_id and s.table_id = r.table_id
  where r.id = p_request_id;
end;
$$;
revoke all on function public.gs_customer_table_order_request_status(uuid, uuid) from public;
grant execute on function public.gs_customer_table_order_request_status(uuid, uuid)
  to anon, authenticated;

create or replace function public.gs_staff_list_customer_table_order_requests()
returns table(request_id uuid, table_number integer, floor_name text, visit_id bigint,
              submitted_at timestamptz, visit_open boolean, items jsonb)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.gs_can_access('table_orders', 'can_view') then
    raise exception 'Table Orders view permission required';
  end if;

  return query
  select r.id, t.table_number, coalesce(t.floor_name, 'Unassigned floor'), r.visit_id,
    r.submitted_at,
    coalesce(t.occupied = true and v.status = 'open', false),
    coalesce(lines.items, '[]'::jsonb)
  from public.gs_customer_table_order_requests r
  join public.gs_cafe_tables t on t.id = r.table_id
  left join public.gs_table_visits v
    on v.id = r.visit_id and v.table_id = r.table_id
  left join lateral (
    select jsonb_agg(jsonb_build_object(
      'product_id', (line.value->>'product_id')::bigint,
      'product_name', coalesce(p.name, 'Unavailable item'),
      'quantity', (line.value->>'quantity')::integer,
      'instructions', line.value->>'instructions'
    ) order by line.ordinality) as items
    from jsonb_array_elements(r.items) with ordinality as line(value, ordinality)
    left join public.gs_menu_products p
      on p.id = (line.value->>'product_id')::bigint
  ) lines on true
  where r.status = 'pending'
  order by r.submitted_at, r.id
  limit 100;
end;
$$;
revoke all on function public.gs_staff_list_customer_table_order_requests() from public, anon;
grant execute on function public.gs_staff_list_customer_table_order_requests() to authenticated;

create or replace function public.gs_staff_accept_customer_table_order_request(p_request_id uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  r public.gs_customer_table_order_requests%rowtype;
  v_table_number integer;
  v_order_id bigint;
  v_cart jsonb;
begin
  if auth.uid() is null
     or not public.gs_can_access('table_orders', 'can_edit')
     or not public.gs_can_access('table_orders', 'can_create') then
    raise exception 'Table Orders edit and create permissions required';
  end if;

  select * into r from public.gs_customer_table_order_requests
  where id = p_request_id for update;
  if not found then raise exception 'Customer order request not found'; end if;
  if r.status = 'accepted' then return r.order_id; end if;
  if r.status <> 'pending' then raise exception 'Request is no longer pending'; end if;

  select t.table_number into v_table_number
  from public.gs_cafe_tables t
  join public.gs_table_visits v
    on v.table_id = t.id and v.id = r.visit_id and v.status = 'open'
  where t.id = r.table_id and t.occupied = true
  for update of t, v;
  if not found then raise exception 'The table visit has ended'; end if;

  select jsonb_agg(jsonb_build_object(
    'product_id', (line.value->>'product_id')::bigint,
    'quantity', (line.value->>'quantity')::integer
  ) order by line.ordinality) into v_cart
  from jsonb_array_elements(r.items) with ordinality as line(value, ordinality);

  -- Existing RPC recalculates prices from current server configuration.
  v_order_id := public.gs_create_cart_order(
    v_table_number::text, false, v_table_number, v_cart
  );
  update public.gs_orders
  set table_visit_id = r.visit_id
  where id = v_order_id and (table_visit_id is null or table_visit_id = r.visit_id);
  if not found then raise exception 'Could not bind order to its active visit'; end if;

  update public.gs_order_items i
  set preparation_notes = nullif(btrim(line.value->>'instructions'), '')
  from jsonb_array_elements(r.items) as line(value)
  where i.order_id = v_order_id
    and i.product_id = (line.value->>'product_id')::bigint;

  update public.gs_customer_table_order_requests
  set status = 'accepted', order_id = v_order_id,
      reviewed_at = now(), reviewed_by = auth.uid()
  where id = r.id and status = 'pending';
  if not found then raise exception 'Request changed while being accepted'; end if;
  insert into public.gs_customer_table_order_request_events(
    request_id, event_type, actor_user_id, order_id
  ) values (r.id, 'accepted', auth.uid(), v_order_id);
  return v_order_id;
end;
$$;
revoke all on function public.gs_staff_accept_customer_table_order_request(uuid) from public, anon;
grant execute on function public.gs_staff_accept_customer_table_order_request(uuid) to authenticated;

create or replace function public.gs_staff_reject_customer_table_order_request(
  p_request_id uuid,
  p_reason text
) returns void language plpgsql security definer set search_path = '' as $$
declare
  r public.gs_customer_table_order_requests%rowtype;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if auth.uid() is null or not public.gs_can_access('table_orders', 'can_edit') then
    raise exception 'Table Orders edit permission required';
  end if;
  if char_length(v_reason) not between 3 and 300 then
    raise exception 'A rejection reason of 3–300 characters is required';
  end if;
  select * into r from public.gs_customer_table_order_requests
  where id = p_request_id for update;
  if not found then raise exception 'Customer order request not found'; end if;
  if r.status = 'rejected' and r.rejection_reason = v_reason then return; end if;
  if r.status <> 'pending' then raise exception 'Request is no longer pending'; end if;

  update public.gs_customer_table_order_requests
  set status = 'rejected', rejection_reason = v_reason,
      reviewed_at = now(), reviewed_by = auth.uid()
  where id = r.id and status = 'pending';
  if not found then raise exception 'Request changed while being rejected'; end if;
  insert into public.gs_customer_table_order_request_events(
    request_id, event_type, actor_user_id, reason
  ) values (r.id, 'rejected', auth.uid(), v_reason);
end;
$$;
revoke all on function public.gs_staff_reject_customer_table_order_request(uuid, text) from public, anon;
grant execute on function public.gs_staff_reject_customer_table_order_request(uuid, text)
  to authenticated;
