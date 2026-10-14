-- Release 1.0.0.12 Menu management.
-- Additive only: retain existing product IDs, order lines, recipes and stock links.
-- Requires the verified application baseline plus menu and preparation-routing tables.
do $$
begin
  if to_regclass('public.gs_menu_products') is null
     or to_regclass('public.gs_cafe_product_preparation') is null
     or to_regclass('public.gs_cafe_preparation_stations') is null
     or to_regclass('public.employee_profiles') is null
     or to_regclass('public.employee_section_permissions') is null
     or to_regclass('public.cafe_website_settings') is null then
    raise exception 'Menu migration requires the verified employee, menu, and preparation-routing schema';
  end if;
end;
$$;

alter table public.gs_menu_products
  add column if not exists description text not null default '',
  add column if not exists category text not null default 'Uncategorized',
  add column if not exists image_path text,
  add column if not exists preparation_minutes integer,
  add column if not exists dietary_tags text[] not null default '{}',
  add column if not exists display_order integer not null default 0,
  add column if not exists version integer not null default 1,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists owner_price_iqd bigint;

alter table public.gs_menu_products
  drop constraint if exists gs_menu_description_length,
  drop constraint if exists gs_menu_category_length,
  drop constraint if exists gs_menu_preparation_minutes_range,
  drop constraint if exists gs_menu_display_order_nonnegative,
  drop constraint if exists gs_menu_version_positive,
  drop constraint if exists gs_menu_dietary_tags_count,
  drop constraint if exists gs_menu_owner_price_nonnegative;

alter table public.gs_menu_products
  add constraint gs_menu_description_length
    check (length(description) <= 1200),
  add constraint gs_menu_category_length
    check (length(trim(category)) between 1 and 80),
  add constraint gs_menu_preparation_minutes_range
    check (preparation_minutes is null or preparation_minutes between 0 and 600),
  add constraint gs_menu_display_order_nonnegative
    check (display_order >= 0),
  add constraint gs_menu_version_positive
    check (version >= 1),
  add constraint gs_menu_dietary_tags_count
    check (cardinality(dietary_tags) <= 20),
  add constraint gs_menu_owner_price_nonnegative
    check (owner_price_iqd is null or owner_price_iqd between 0 and 1000000000);

create index if not exists gs_menu_products_category_order_idx
  on public.gs_menu_products (category, display_order, name);
create index if not exists gs_menu_products_active_order_idx
  on public.gs_menu_products (is_active, display_order, name);

create table if not exists public.gs_menu_product_revisions (
  id uuid primary key default gen_random_uuid(),
  product_id bigint references public.gs_menu_products(id) on delete restrict,
  base_version integer,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'conflict')),
  submitted_by uuid not null references auth.users(id),
  reviewed_by uuid references auth.users(id),
  idempotency_key uuid not null,
  request_hash text not null check (length(request_hash) = 32),
  review_note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint gs_menu_revision_base_version
    check ((product_id is null and base_version is null)
        or (product_id is not null and base_version >= 1)),
  unique (submitted_by, idempotency_key)
);

create index if not exists gs_menu_revisions_pending_idx
  on public.gs_menu_product_revisions (created_at desc)
  where status = 'pending';
create index if not exists gs_menu_revisions_product_idx
  on public.gs_menu_product_revisions (product_id, created_at desc);

create table if not exists public.gs_menu_audit_events (
  id bigint generated always as identity primary key,
  product_id bigint references public.gs_menu_products(id) on delete restrict,
  revision_id uuid references public.gs_menu_product_revisions(id) on delete restrict,
  actor_id uuid not null references auth.users(id),
  action text not null check (action in (
    'revision_submitted',
    'revision_approved',
    'revision_rejected',
    'revision_conflict',
    'availability_changed'
  )),
  request_id uuid not null,
  before_state jsonb,
  after_state jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists gs_menu_audit_product_idx
  on public.gs_menu_audit_events (product_id, occurred_at desc);
create index if not exists gs_menu_audit_revision_idx
  on public.gs_menu_audit_events (revision_id, occurred_at desc);
create unique index if not exists gs_menu_audit_actor_request_action_uniq
  on public.gs_menu_audit_events (actor_id, request_id, action);

alter table public.gs_menu_product_revisions enable row level security;
alter table public.gs_menu_audit_events enable row level security;

create or replace function public.gs_menu_mfa_access(p_action text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select auth.uid() is not null
     and coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
     and public.gs_can_access('menu', p_action);
$$;
revoke all on function public.gs_menu_mfa_access(text) from public, anon;
grant execute on function public.gs_menu_mfa_access(text) to authenticated;

drop policy if exists gs_menu_revisions_read on public.gs_menu_product_revisions;
create policy gs_menu_revisions_read
  on public.gs_menu_product_revisions for select to authenticated
  using (
    public.gs_menu_mfa_access('can_view')
    and (
      submitted_by = (select auth.uid())
      or exists (
        select 1
          from public.employee_profiles employee
         where employee.user_id = (select auth.uid())
           and employee.is_active = true
           and lower(btrim(coalesce(employee.role, ''))) = 'owner'
      )
    )
  );

drop policy if exists gs_menu_audit_read on public.gs_menu_audit_events;
create policy gs_menu_audit_read
  on public.gs_menu_audit_events for select to authenticated
  using (public.gs_menu_mfa_access('can_view'));

-- No direct insert/update/delete policies are provided for revisions or audit events.

insert into storage.buckets (id, name, public)
values ('gs-menu-product-images', 'gs-menu-product-images', true)
on conflict (id) do update set public = true;

drop policy if exists gs_menu_product_images_public_read on storage.objects;
create policy gs_menu_product_images_public_read
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'gs-menu-product-images');

drop policy if exists gs_menu_product_images_employee_upload on storage.objects;
create policy gs_menu_product_images_employee_upload
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'gs-menu-product-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and coalesce((select auth.jwt() ->> 'aal'), '') = 'aal2'
    and public.gs_can_access('menu', 'can_edit')
    and exists (
      select 1
        from public.employee_profiles employee
       where employee.user_id = (select auth.uid())
         and employee.is_active = true
    )
  );

create or replace function public.gs_menu_user_is_owner()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select public.gs_menu_mfa_access('can_edit')
     and exists (
       select 1
         from public.employee_profiles employee
        where employee.user_id = auth.uid()
          and employee.is_active = true
          and lower(btrim(coalesce(employee.role, ''))) = 'owner'
     );
$$;
revoke all on function public.gs_menu_user_is_owner() from public, anon;
grant execute on function public.gs_menu_user_is_owner() to authenticated;

create or replace function public.gs_menu_station_directory()
returns table (station_key text, display_name text, enabled boolean)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.gs_menu_mfa_access('can_view') then
    raise exception 'MFA Menu view permission required' using errcode = '42501';
  end if;

  return query
  select station.station_key, station.display_name, station.enabled
    from public.gs_cafe_preparation_stations station
   order by station.display_name, station.station_key;
end;
$$;
revoke all on function public.gs_menu_station_directory() from public, anon;
grant execute on function public.gs_menu_station_directory() to authenticated;

create or replace function public.gs_menu_admin_products()
returns table (
  id bigint,
  name text,
  barcode text,
  description text,
  category text,
  normal_price_iqd bigint,
  tourism_price_iqd bigint,
  owner_price_iqd bigint,
  is_active boolean,
  image_path text,
  preparation_minutes integer,
  dietary_tags text[],
  display_order integer,
  version integer,
  station_key text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.gs_menu_mfa_access('can_view') then
    raise exception 'Menu view permission required' using errcode = '42501';
  end if;

  return query
  select product.id,
         product.name,
         product.barcode,
         product.description,
         product.category,
         product.normal_price_iqd,
         product.tourism_price_iqd,
         product.owner_price_iqd,
         product.is_active,
         product.image_path,
         product.preparation_minutes,
         product.dietary_tags,
         product.display_order,
         product.version,
         preparation.station_key,
         product.created_at,
         product.updated_at
    from public.gs_menu_products product
    left join public.gs_cafe_product_preparation preparation
      on preparation.product_id = product.id
   order by product.display_order, product.name, product.id;
end;
$$;
revoke all on function public.gs_menu_admin_products() from public, anon;
grant execute on function public.gs_menu_admin_products() to authenticated;

create or replace function public.gs_menu_category_summary()
returns table (category text, product_count bigint, active_count bigint)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.gs_menu_mfa_access('can_view') then
    raise exception 'Menu view permission required' using errcode = '42501';
  end if;

  return query
  select product.category,
         count(*)::bigint,
         count(*) filter (where product.is_active)::bigint
    from public.gs_menu_products product
   group by product.category
   order by product.category;
end;
$$;
revoke all on function public.gs_menu_category_summary() from public, anon;
grant execute on function public.gs_menu_category_summary() to authenticated;

create or replace function public.gs_menu_submit_product_revision(
  p_product_id bigint,
  p_expected_version integer,
  p_payload jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_action text;
  v_current_version integer;
  v_name text;
  v_barcode text;
  v_description text;
  v_category text;
  v_normal bigint;
  v_tourism bigint;
  v_owner bigint;
  v_preparation integer;
  v_station text;
  v_image text;
  v_tags text[];
  v_display_order integer;
  v_revision uuid;
  v_request_hash text;
  v_saved_hash text;
begin
  if v_uid is null
     or coalesce(auth.jwt() ->> 'aal', '') <> 'aal2'
     or not exists (
       select 1 from public.employee_profiles employee
        where employee.user_id = v_uid and employee.is_active = true
     ) then
    raise exception 'Active MFA employee session required' using errcode = '42501';
  end if;

  if p_idempotency_key is null or p_payload is null
     or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'A valid product revision and idempotency key are required'
      using errcode = '22023';
  end if;

  if p_product_id is null then
    v_action := 'can_create';
    if p_expected_version is not null then
      raise exception 'New products cannot have a base version' using errcode = '22023';
    end if;
  else
    v_action := 'can_edit';
    select product.version
      into v_current_version
      from public.gs_menu_products product
     where product.id = p_product_id
     for update;
    if not found then
      raise exception 'Product not found' using errcode = 'P0002';
    end if;
    if p_expected_version is null or p_expected_version <> v_current_version then
      raise exception 'Product changed; refresh and resubmit' using errcode = '40001';
    end if;
  end if;

  if not public.gs_can_access('menu', v_action) then
    raise exception 'Not authorized to submit menu changes' using errcode = '42501';
  end if;

  v_name := nullif(btrim(p_payload ->> 'name'), '');
  v_barcode := nullif(btrim(p_payload ->> 'barcode'), '');
  v_description := coalesce(p_payload ->> 'description', '');
  v_category := coalesce(nullif(btrim(p_payload ->> 'category'), ''), 'Uncategorized');
  v_image := nullif(btrim(p_payload ->> 'image_path'), '');
  v_station := nullif(btrim(p_payload ->> 'station_key'), '');

  if coalesce(p_payload ->> 'normal_price_iqd', '') !~ '^[0-9]+$'
     or coalesce(p_payload ->> 'tourism_price_iqd', '') !~ '^[0-9]+$'
     or (nullif(p_payload ->> 'owner_price_iqd', '') is not null
         and p_payload ->> 'owner_price_iqd' !~ '^[0-9]+$')
     or (nullif(p_payload ->> 'preparation_minutes', '') is not null
         and p_payload ->> 'preparation_minutes' !~ '^[0-9]+$')
     or (nullif(p_payload ->> 'display_order', '') is not null
         and p_payload ->> 'display_order' !~ '^[0-9]+$') then
    raise exception 'Menu prices, preparation time, and display order must be whole numbers'
      using errcode = '22023';
  end if;

  begin
    v_normal := (p_payload ->> 'normal_price_iqd')::bigint;
    v_tourism := (p_payload ->> 'tourism_price_iqd')::bigint;
    v_owner := nullif(p_payload ->> 'owner_price_iqd', '')::bigint;
    v_preparation := nullif(p_payload ->> 'preparation_minutes', '')::integer;
    v_display_order := coalesce(nullif(p_payload ->> 'display_order', '')::integer, 0);
  exception when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'Invalid numeric menu field' using errcode = '22023';
  end;

  if v_name is null or length(v_name) > 150
     or v_barcode is null or length(v_barcode) > 80
     or length(v_description) > 1200
     or length(v_category) > 80
     or v_normal is null
     or v_tourism is null
     or v_normal not between 0 and 1000000000
     or v_tourism not between 0 and 1000000000
     or (v_owner is not null and v_owner not between 0 and 1000000000)
     or (v_preparation is not null and v_preparation not between 0 and 600)
     or v_display_order not between 0 and 1000000 then
    raise exception 'Invalid menu product details' using errcode = '22023';
  end if;

  if jsonb_typeof(coalesce(p_payload -> 'dietary_tags', '[]'::jsonb)) <> 'array'
     or jsonb_array_length(coalesce(p_payload -> 'dietary_tags', '[]'::jsonb)) > 20 then
    raise exception 'Dietary tags must be an array with at most 20 values'
      using errcode = '22023';
  end if;

  if exists (
    select 1
      from jsonb_array_elements_text(
        coalesce(p_payload -> 'dietary_tags', '[]'::jsonb)
      ) as tags(value)
     where value is null or length(btrim(value)) = 0
  ) then
    raise exception 'Dietary tags cannot be empty' using errcode = '22023';
  end if;

  select coalesce(array_agg(distinct lower(btrim(value))), '{}'::text[])
    into v_tags
    from jsonb_array_elements_text(
      coalesce(p_payload -> 'dietary_tags', '[]'::jsonb)
    ) as tags(value);

  if exists (
    select 1 from unnest(v_tags) tag
     where tag not in ('vegetarian', 'vegan', 'gluten_free', 'spicy', 'halal')
  ) then
    raise exception 'Unsupported dietary tag' using errcode = '22023';
  end if;

  if v_station is not null and not exists (
    select 1 from public.gs_cafe_preparation_stations station
     where station.station_key = v_station and station.enabled = true
  ) then
    raise exception 'Preparation station is unavailable' using errcode = '22023';
  end if;

  if v_image is not null and (
    length(v_image) > 500
    or v_image like '%..%'
    or not exists (
      select 1 from storage.objects object
       where object.bucket_id = 'gs-menu-product-images'
         and object.name = v_image
    )
  ) then
    raise exception 'Product image is not an uploaded menu image'
      using errcode = '22023';
  end if;

  v_request_hash := md5(
    coalesce(p_product_id::text, 'new') || '|' ||
    coalesce(p_expected_version::text, '') || '|' || p_payload::text
  );

  insert into public.gs_menu_product_revisions (
    product_id, base_version, payload, submitted_by,
    idempotency_key, request_hash
  ) values (
    p_product_id, p_expected_version, p_payload, v_uid,
    p_idempotency_key, v_request_hash
  )
  on conflict (submitted_by, idempotency_key) do nothing
  returning id into v_revision;

  if v_revision is null then
    select revision.id, revision.request_hash
      into v_revision, v_saved_hash
      from public.gs_menu_product_revisions revision
     where revision.submitted_by = v_uid
       and revision.idempotency_key = p_idempotency_key;
    if v_saved_hash is distinct from v_request_hash then
      raise exception 'Idempotency key was already used for different menu data'
        using errcode = '22023';
    end if;
    return v_revision;
  end if;

  insert into public.gs_menu_audit_events (
    product_id, revision_id, actor_id, action, request_id, after_state
  ) values (
    p_product_id, v_revision, v_uid, 'revision_submitted',
    p_idempotency_key, p_payload
  );

  return v_revision;
end;
$$;
revoke all on function public.gs_menu_submit_product_revision(bigint, integer, jsonb, uuid)
  from public, anon;
grant execute on function public.gs_menu_submit_product_revision(bigint, integer, jsonb, uuid)
  to authenticated;

create or replace function public.gs_menu_review_product_revision(
  p_revision_id uuid,
  p_decision text,
  p_expected_version integer,
  p_note text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_revision public.gs_menu_product_revisions%rowtype;
  v_payload jsonb;
  v_before jsonb;
  v_product_id bigint;
  v_version integer;
  v_station text;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if v_uid is null
     or coalesce(auth.jwt() ->> 'aal', '') <> 'aal2'
     or not public.gs_menu_user_is_owner()
     or not public.gs_can_access('menu', 'can_edit') then
    raise exception 'Owner MFA session with Menu edit permission required'
      using errcode = '42501';
  end if;

  if p_revision_id is null
     or p_decision is null
     or p_decision not in ('approve', 'reject')
     or (p_decision = 'reject' and (v_note is null or length(v_note) > 500))
     or (p_note is not null and length(p_note) > 500) then
    raise exception 'Invalid menu review decision or note' using errcode = '22023';
  end if;

  select revision.*
    into v_revision
    from public.gs_menu_product_revisions revision
   where revision.id = p_revision_id
   for update;
  if not found then
    raise exception 'Menu revision not found' using errcode = 'P0002';
  end if;
  if v_revision.status <> 'pending' then
    raise exception 'Menu revision has already been reviewed' using errcode = '40001';
  end if;

  if p_decision = 'approve'
     and v_revision.product_id is null
     and not public.gs_can_access('menu', 'can_create') then
    raise exception 'Menu create permission required to approve a new product'
      using errcode = '42501';
  end if;

  if p_decision = 'reject' then
    update public.gs_menu_product_revisions
       set status = 'rejected', reviewed_by = v_uid,
           reviewed_at = now(), review_note = v_note
     where id = p_revision_id;
    insert into public.gs_menu_audit_events (
      product_id, revision_id, actor_id, action, request_id, after_state
    ) values (
      v_revision.product_id, p_revision_id, v_uid, 'revision_rejected',
      v_revision.idempotency_key, jsonb_build_object('note', v_note)
    );
    return jsonb_build_object('status', 'rejected', 'product_id', v_revision.product_id);
  end if;

  if p_expected_version is distinct from v_revision.base_version then
    raise exception 'Review version does not match the submitted revision'
      using errcode = '40001';
  end if;

  v_payload := v_revision.payload;
  v_station := nullif(btrim(v_payload ->> 'station_key'), '');

  if v_revision.product_id is null then
    insert into public.gs_menu_products (
      name, barcode, description, category, normal_price_iqd,
      tourism_price_iqd, owner_price_iqd, image_path, preparation_minutes,
      dietary_tags, display_order, is_active, version, updated_at
    ) values (
      v_payload ->> 'name',
      v_payload ->> 'barcode',
      coalesce(v_payload ->> 'description', ''),
      coalesce(nullif(btrim(v_payload ->> 'category'), ''), 'Uncategorized'),
      (v_payload ->> 'normal_price_iqd')::bigint,
      (v_payload ->> 'tourism_price_iqd')::bigint,
      nullif(v_payload ->> 'owner_price_iqd', '')::bigint,
      nullif(btrim(v_payload ->> 'image_path'), ''),
      nullif(v_payload ->> 'preparation_minutes', '')::integer,
      array(select jsonb_array_elements_text(
        coalesce(v_payload -> 'dietary_tags', '[]'::jsonb)
      )),
      coalesce(nullif(v_payload ->> 'display_order', '')::integer, 0),
      true,
      1,
      now()
    ) returning id, version into v_product_id, v_version;
  else
    select to_jsonb(product)
      into v_before
      from public.gs_menu_products product
     where product.id = v_revision.product_id
     for update;
    select product.version
      into v_version
      from public.gs_menu_products product
     where product.id = v_revision.product_id;

    if not found or v_version is distinct from v_revision.base_version then
      update public.gs_menu_product_revisions
         set status = 'conflict', reviewed_by = v_uid,
             reviewed_at = now(),
             review_note = 'Catalog changed after this revision was submitted.'
       where id = p_revision_id;
      insert into public.gs_menu_audit_events (
        product_id, revision_id, actor_id, action, request_id, before_state, after_state
      ) values (
        v_revision.product_id, p_revision_id, v_uid, 'revision_conflict',
        v_revision.idempotency_key, v_before,
        jsonb_build_object('status', 'conflict')
      );
      return jsonb_build_object(
        'status', 'conflict',
        'product_id', v_revision.product_id,
        'current_version', v_version
      );
    end if;

    update public.gs_menu_products
       set name = v_payload ->> 'name',
           barcode = v_payload ->> 'barcode',
           description = coalesce(v_payload ->> 'description', ''),
           category = coalesce(nullif(btrim(v_payload ->> 'category'), ''), 'Uncategorized'),
           normal_price_iqd = (v_payload ->> 'normal_price_iqd')::bigint,
           tourism_price_iqd = (v_payload ->> 'tourism_price_iqd')::bigint,
           owner_price_iqd = nullif(v_payload ->> 'owner_price_iqd', '')::bigint,
           image_path = nullif(btrim(v_payload ->> 'image_path'), ''),
           preparation_minutes = nullif(v_payload ->> 'preparation_minutes', '')::integer,
           dietary_tags = array(select jsonb_array_elements_text(
             coalesce(v_payload -> 'dietary_tags', '[]'::jsonb)
           )),
           display_order = coalesce(nullif(v_payload ->> 'display_order', '')::integer, 0),
           version = version + 1,
           updated_at = now()
     where id = v_revision.product_id
     returning id, version into v_product_id, v_version;
  end if;

  if v_station is null then
    delete from public.gs_cafe_product_preparation
     where product_id = v_product_id;
  else
    if not exists (
      select 1 from public.gs_cafe_preparation_stations station
       where station.station_key = v_station and station.enabled = true
    ) then
      raise exception 'Preparation station is no longer available'
        using errcode = '40001';
    end if;
    insert into public.gs_cafe_product_preparation (
      product_id, station_key, updated_by, updated_at
    ) values (v_product_id, v_station, v_uid, now())
    on conflict (product_id) do update
      set station_key = excluded.station_key,
          updated_by = excluded.updated_by,
          updated_at = excluded.updated_at;
  end if;

  update public.gs_menu_product_revisions
     set status = 'approved', reviewed_by = v_uid,
         reviewed_at = now(), review_note = v_note
   where id = p_revision_id;

  insert into public.gs_menu_audit_events (
    product_id, revision_id, actor_id, action, request_id,
    before_state, after_state
  ) values (
    v_product_id, p_revision_id, v_uid, 'revision_approved',
    v_revision.idempotency_key, v_before, v_payload
  );

  return jsonb_build_object(
    'status', 'approved',
    'product_id', v_product_id,
    'version', v_version
  );
end;
$$;
revoke all on function public.gs_menu_review_product_revision(uuid, text, integer, text)
  from public, anon;
grant execute on function public.gs_menu_review_product_revision(uuid, text, integer, text)
  to authenticated;

create or replace function public.gs_menu_set_product_availability(
  p_product_id bigint,
  p_is_active boolean,
  p_expected_version integer,
  p_request_id uuid
)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_current public.gs_menu_products%rowtype;
  v_existing_product_id bigint;
  v_existing_after_state jsonb;
  v_version integer;
begin
  if v_uid is null
     or coalesce(auth.jwt() ->> 'aal', '') <> 'aal2'
     or not exists (
       select 1 from public.employee_profiles employee
        where employee.user_id = v_uid and employee.is_active = true
     )
     or not public.gs_can_access('menu', 'can_edit') then
    raise exception 'Active MFA employee with Menu edit permission required'
      using errcode = '42501';
  end if;
  if p_product_id is null or p_is_active is null or p_expected_version is null
     or p_request_id is null then
    raise exception 'Product, status, version and request ID are required'
      using errcode = '22023';
  end if;

  select product.*
    into v_current
    from public.gs_menu_products product
   where product.id = p_product_id
   for update;
  if not found then
    raise exception 'Product not found' using errcode = 'P0002';
  end if;

  select event.product_id, event.after_state
    into v_existing_product_id, v_existing_after_state
    from public.gs_menu_audit_events event
   where event.actor_id = v_uid
     and event.request_id = p_request_id
     and event.action = 'availability_changed';
  if found then
    if v_existing_product_id is distinct from p_product_id
       or v_existing_after_state ->> 'is_active' is distinct from p_is_active::text then
      raise exception 'Availability request ID was already used for a different change'
        using errcode = '22023';
    end if;
    return (v_existing_after_state ->> 'version')::integer;
  end if;

  -- A timed-out retry of the same target state is a no-op, not a second change.
  if v_current.is_active = p_is_active then
    return v_current.version;
  end if;
  if v_current.version <> p_expected_version then
    raise exception 'Product changed; refresh before changing availability'
      using errcode = '40001';
  end if;

  update public.gs_menu_products
     set is_active = p_is_active,
         version = version + 1,
         updated_at = now()
   where id = p_product_id
   returning version into v_version;

  insert into public.gs_menu_audit_events (
    product_id, actor_id, action, request_id, before_state, after_state
  ) values (
    p_product_id, v_uid, 'availability_changed', p_request_id,
    jsonb_build_object('is_active', v_current.is_active, 'version', v_current.version),
    jsonb_build_object('is_active', p_is_active, 'version', v_version)
  );

  return v_version;
end;
$$;
revoke all on function public.gs_menu_set_product_availability(bigint, boolean, integer, uuid)
  from public, anon;
grant execute on function public.gs_menu_set_product_availability(bigint, boolean, integer, uuid)
  to authenticated;

create or replace function public.gs_menu_public_catalog()
returns table (
  product_id bigint,
  name text,
  description text,
  category text,
  price_iqd bigint,
  image_path text,
  dietary_tags text[],
  display_order integer
)
language sql stable security definer set search_path = ''
as $$
  select product.id,
         product.name,
         product.description,
         product.category,
         product.normal_price_iqd,
         product.image_path,
         product.dietary_tags,
         product.display_order
    from public.gs_menu_products product
   where product.is_active = true
     and exists (
       select 1 from public.cafe_website_settings settings
        where settings.id = 1 and settings.menu_enabled = true
     )
   order by product.category, product.display_order, product.name
   limit 500;
$$;
revoke all on function public.gs_menu_public_catalog() from public;
grant execute on function public.gs_menu_public_catalog() to anon, authenticated;

-- Disable legacy direct-publish endpoints so all catalog edits use owner approval.
revoke all on function public.gs_create_menu_product(text, text, bigint, bigint)
  from public, anon, authenticated;
revoke all on function public.gs_update_menu_product(bigint, text, text, bigint, bigint, boolean)
  from public, anon, authenticated;
