-- SSR SPACE migration 02: izinkan buat org + membership sendiri
-- Jalankan di Supabase Dashboard -> SQL Editor (sekali saja).

alter table organizations enable row level security;
alter table org_members enable row level security;

drop policy if exists "auth create org" on organizations;
create policy "auth create org" on organizations
  for insert to authenticated with check (true);

drop policy if exists "own memberships" on org_members;
create policy "own memberships" on org_members
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "join own org" on org_members;
create policy "join own org" on org_members
  for insert to authenticated with check (user_id = auth.uid());
