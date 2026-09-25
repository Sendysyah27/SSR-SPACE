-- SSR SPACE migration 11: rate limit auto-insert + audit log + client error log
-- Jalankan di Supabase Dashboard → SQL Editor SETELAH migration_10.
-- Menutup backlog A3 (rate limit), A4 (audit log), dan error monitoring in-house.

-- ============================================================
-- A3: rate limit auto-insert: 10 insert auto / 60 detik / org
-- Insert dari form (source_package is null) tidak kena.
-- ============================================================
create index if not exists transactions_auto_org_created_idx
  on transactions (org_id, created_at)
  where source_package is not null;

create or replace function public.enforce_auto_tx_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  if new.source_package is null then
    return new;
  end if;

  select count(*) into v_count
  from transactions
  where org_id = new.org_id
    and source_package is not null
    and created_at > now() - interval '60 seconds';

  if v_count >= 10 then
    raise exception 'RATE_LIMITED';
  end if;

  return new;
end $$;

drop trigger if exists trg_rate_limit_auto_tx on transactions;
create trigger trg_rate_limit_auto_tx
  before insert on transactions
  for each row
  execute function public.enforce_auto_tx_rate_limit();

-- ============================================================
-- A4: audit log server: insert otomatis + join org
-- Client TANPA policy INSERT/UPDATE/DELETE (deny total); SELECT member saja.
-- ============================================================
create table if not exists audit_logs (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organizations(id) on delete cascade,
  actor_user_id uuid,
  event         text not null,
  meta          jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);

alter table audit_logs enable row level security;

-- Subquery ke org_members dari tabel LAIN aman (bukan policy di org_members).
drop policy if exists "member read audit_logs" on audit_logs;
create policy "member read audit_logs" on audit_logs
  for select using (
    exists (
      select 1 from org_members m
      where m.org_id = audit_logs.org_id and m.user_id = auth.uid()
    )
  );

create index if not exists audit_logs_org_created_idx
  on audit_logs (org_id, created_at desc);

create or replace function public.log_auto_tx_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.source_package is null then
    return new;
  end if;
  insert into audit_logs (org_id, actor_user_id, event, meta)
  values (
    new.org_id,
    auth.uid(),
    'tx_auto_insert',
    jsonb_build_object(
      'tx_id', new.id,
      'amount', new.amount,
      'type', new.type,
      'source_package', new.source_package,
      'date', new.date
    )
  );
  return new;
end $$;

drop trigger if exists trg_audit_auto_tx on transactions;
create trigger trg_audit_auto_tx
  after insert on transactions
  for each row
  execute function public.log_auto_tx_insert();

create or replace function public.log_org_join()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into audit_logs (org_id, actor_user_id, event, meta)
  values (new.org_id, new.user_id, 'org_join', jsonb_build_object('role', new.role));
  return new;
end $$;

drop trigger if exists trg_audit_org_join on org_members;
create trigger trg_audit_org_join
  after insert on org_members
  for each row
  execute function public.log_org_join();

-- ============================================================
-- Error monitoring in-house: client_errors (ditulis client Task 2)
-- ============================================================
create table if not exists client_errors (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid,
  org_id      uuid,
  message     text not null,
  stack       text,
  context     text,
  app_version text not null,
  created_at  timestamptz not null default now()
);

alter table client_errors enable row level security;

drop policy if exists "own client_errors insert" on client_errors;
create policy "own client_errors insert" on client_errors
  for insert with check (user_id = auth.uid());

drop policy if exists "own client_errors read" on client_errors;
create policy "own client_errors read" on client_errors
  for select using (user_id = auth.uid());

create index if not exists client_errors_user_created_idx
  on client_errors (user_id, created_at desc);
