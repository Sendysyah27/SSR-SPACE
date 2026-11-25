-- ========== migration_31_security_policies.sql ==========
-- SSR SPACE migration 31: patch keamanan RLS (audit 2026-11-25).
-- Jalankan di Supabase Dashboard -> SQL Editor (sekali; idempotent)
-- SETELAH migration_30.
--
-- Menutup 2 temuan audit:
-- [P0] Klien bisa membuat workspace sendiri ber-plan='pro' -> bypass seluruh
--      paywall/kuota, karena org_plan() membaca organizations.plan. Policy
--      INSERT lama hanya mengunci created_by; sisanya dikirim klien.
--      Fix: paksa plan='free' + plan_expires_at null saat create dari klien.
-- [P1] org_members.role tanpa CHECK + cabang admin pada policy "join own org"
--      tanpa syarat role -> admin bisa meng-insert anggota ber-role='owner'
--      (naik pangkat ke owner yang boleh hapus workspace).
--      Fix: CHECK role + admin hanya boleh menambah member/admin.

-- [P0] organizations: klien tak boleh mengangkat plan sendiri.
alter table organizations alter column plan set default 'free';

drop policy if exists "auth create org" on organizations;
create policy "auth create org" on organizations
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and plan = 'free'
    and plan_expires_at is null
  );

-- [P1] org_members: batasi nilai role.
alter table org_members drop constraint if exists org_members_role_chk;
alter table org_members add constraint org_members_role_chk
  check (role in ('owner', 'admin', 'member'));

-- [P1] join own org: creator self-join (boleh owner); admin hanya member/admin.
drop policy if exists "join own org" on org_members;
create policy "join own org" on org_members
  for insert to authenticated
  with check (
    (
      user_id = auth.uid()
      and public.is_org_creator(org_id)
    )
    or (
      public.is_org_admin(org_id)
      and role in ('member', 'admin')
    )
  );
