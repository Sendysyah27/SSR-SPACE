-- SSR SPACE migration 04: subscriptions untuk billing Free/Pro
create table if not exists subscriptions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references organizations(id) on delete cascade,
  plan text not null,
  status text not null default 'pending',
  amount numeric not null default 0,
  snap_token text,
  created_at timestamptz default now()
);

alter table subscriptions enable row level security;

drop policy if exists "member subscriptions" on subscriptions;
create policy "member subscriptions" on subscriptions for all
  using (exists (select 1 from org_members m where m.org_id = subscriptions.org_id and m.user_id = auth.uid()))
  with check (exists (select 1 from org_members m where m.org_id = subscriptions.org_id and m.user_id = auth.uid()));
