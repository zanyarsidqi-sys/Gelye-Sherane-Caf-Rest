-- Upgrade 265: revision event and print/notification outbox FOUNDATION.
-- No public or employee direct writes: future audited, transactional order-edit
-- RPC must insert revisions and outbox rows in the same transaction.
create table if not exists public.gs_order_revision_events (
 id uuid primary key default gen_random_uuid(),
 order_id bigint not null,
 order_item_id bigint,
 revision_number integer not null check (revision_number > 0),
 change_type text not null check (change_type in ('add','remove','quantity','instructions','assignment','price_adjustment')),
 before_snapshot jsonb not null default '{}'::jsonb,
 after_snapshot jsonb not null default '{}'::jsonb,
 changed_by uuid not null,
 changed_at timestamptz not null default now(),
 reason text,
 unique(order_id, revision_number, order_item_id, change_type)
);
create table if not exists public.gs_order_revision_dispatch (
 id uuid primary key default gen_random_uuid(),
 revision_id uuid not null references public.gs_order_revision_events(id) on delete restrict,
 destination_type text not null check(destination_type in ('station_print','employee_notification','customer_update')),
 destination_key text not null,
 status text not null default 'pending' check(status in ('pending','claimed','sent','acknowledged','failed')),
 attempts integer not null default 0 check(attempts >= 0),
 created_at timestamptz not null default now(),
 last_attempt_at timestamptz,
 acknowledged_at timestamptz,
 unique(revision_id,destination_type,destination_key)
);
create index if not exists gs_order_revision_events_order_idx
 on public.gs_order_revision_events(order_id,revision_number,changed_at);
create index if not exists gs_order_revision_dispatch_queue_idx
 on public.gs_order_revision_dispatch(status,created_at);
alter table public.gs_order_revision_events enable row level security;
alter table public.gs_order_revision_dispatch enable row level security;
revoke all on public.gs_order_revision_events from public,anon,authenticated;
revoke all on public.gs_order_revision_dispatch from public,anon,authenticated;
-- No RLS policies: even authenticated users cannot access these tables directly.
-- Future trusted RPC/worker will need narrowly scoped grants and authorization.
