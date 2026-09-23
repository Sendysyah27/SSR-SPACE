-- SSR SPACE SaaS schema (Supabase Postgres + RLS)
create table if not exists organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  plan text not null default 'free',
  created_at timestamptz default now()
);

create table if not exists org_members (
  org_id uuid references organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role text not null default 'member',
  primary key (org_id, user_id)
);

create table if not exists wallets (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references organizations(id) on delete cascade,
  name text not null,
  type text not null default 'cash',
  created_at timestamptz default now()
);

create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references organizations(id) on delete cascade,
  type text not null,
  amount numeric not null check (amount > 0),
  wallet_id uuid references wallets(id),
  to_wallet_id uuid references wallets(id),
  category text,
  note text,
  date date not null default current_date,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

alter table organizations enable row level security;
alter table org_members enable row level security;
alter table wallets enable row level security;
alter table transactions enable row level security;

drop policy if exists "member read org" on organizations;
create policy "member read org" on organizations for select
  using (exists (select 1 from org_members m where m.org_id = id and m.user_id = auth.uid()));

drop policy if exists "member wallets" on wallets;
create policy "member wallets" on wallets for all
  using (exists (select 1 from org_members m where m.org_id = wallets.org_id and m.user_id = auth.uid()))
  with check (exists (select 1 from org_members m where m.org_id = wallets.org_id and m.user_id = auth.uid()));

drop policy if exists "member tx" on transactions;
create policy "member tx" on transactions for all
  using (exists (select 1 from org_members m where m.org_id = transactions.org_id and m.user_id = auth.uid()))
  with check (exists (select 1 from org_members m where m.org_id = transactions.org_id and m.user_id = auth.uid()));

drop policy if exists "auth create org" on organizations;
create policy "auth create org" on organizations
  for insert to authenticated with check (true);

drop policy if exists "own memberships" on org_members;
create policy "own memberships" on org_members
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "join own org" on org_members;
create policy "join own org" on org_members
  for insert to authenticated with check (user_id = auth.uid());
