-- SSR SPACE migration 08: fix RLS recursion di org_members (akibat migration 07)
-- Jalankan di Supabase Dashboard -> SQL Editor.

-- 1) Helper security definer: cek owner/admin TANPA kena RLS org_members (putus rekursi)
create or replace function public.is_org_admin(p_org_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from org_members
    where org_id = p_org_id
      and user_id = auth.uid()
      and role in ('owner', 'admin')
  );
$$;

revoke execute on function public.is_org_admin(uuid) from public, anon;
grant execute on function public.is_org_admin(uuid) to authenticated;

-- 2) Buang policy SELECT yang self-referencing (penyebab "Gagal memuat dompet")
drop policy if exists "member read org_members" on org_members;

-- SELECT cukup: baca keanggotaan sendiri (sudah cukup utk app + RLS tabel lain)
drop policy if exists "own memberships" on org_members;
create policy "own memberships" on org_members
  for select to authenticated
  using (user_id = auth.uid());

-- 3) INSERT join: self via created_by OR owner/admin via helper (tanpa subquery org_members)
drop policy if exists "join own org" on org_members;
create policy "join own org" on org_members
  for insert to authenticated
  with check (
    (
      user_id = auth.uid()
      and exists (
        select 1 from organizations o
        where o.id = org_id and o.created_by = auth.uid()
      )
    )
    or public.is_org_admin(org_id)
  );
