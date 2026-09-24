-- SSR SPACE migration 03: budgets per kategori per bulan
create table if not exists budgets (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references organizations(id) on delete cascade,
  category text not null,
  month text not null,
  limit_amount numeric not null check (limit_amount > 0),
  created_at timestamptz default now(),
  unique (org_id, category, month)
);

alter table budgets enable row level security;

drop policy if exists "member budgets" on budgets;
create policy "member budgets" on budgets for all
  using (exists (select 1 from org_members m where m.org_id = budgets.org_id and m.user_id = auth.uid()))
  with check (exists (select 1 from org_members m where m.org_id = budgets.org_id and m.user_id = auth.uid()));
