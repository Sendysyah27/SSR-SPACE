-- SSR SPACE migration 14: admin workspace (list/kick/delete via RPC).
-- Jalankan di Supabase Dashboard -> SQL Editor SETELAH migration_13.

-- Daftar anggota: hanya member org tsb (nama/email TIDAK diekspos;
-- client tampilkan ID terpotong + peran + penanda Kamu).
create or replace function public.list_org_members(p_org_id uuid)
returns table (user_id uuid, role text)
language sql
security definer
set search_path = public
as $$
  select m.user_id, m.role from org_members m
  where m.org_id = p_org_id
    and exists (
      select 1 from org_members me
      where me.org_id = p_org_id and me.user_id = auth.uid()
    )
  order by m.role, m.user_id;
$$;

revoke execute on function public.list_org_members(uuid) from public, anon;
grant execute on function public.list_org_members(uuid) to authenticated;

-- Keluarkan anggota: pemanggil owner/admin; tolak target owner terakhir;
-- tolak keluarkan diri sendiri (kode KICK_SELF / KICK_LAST_OWNER / NOT_ADMIN).
create or replace function public.kick_member(p_org_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_myrole text;
  v_target_role text;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  select role into v_myrole from org_members
  where org_id = p_org_id and user_id = v_uid;
  if v_myrole is null or v_myrole not in ('owner', 'admin') then
    raise exception 'NOT_ADMIN';
  end if;
  if p_user_id = v_uid then
    raise exception 'KICK_SELF';
  end if;
  select role into v_target_role from org_members
  where org_id = p_org_id and user_id = p_user_id;
  if v_target_role is null then
    raise exception 'NOT_MEMBER';
  end if;
  if v_target_role = 'owner'
     and (select count(*) from org_members
          where org_id = p_org_id and role = 'owner') <= 1 then
    raise exception 'KICK_LAST_OWNER';
  end if;
  delete from org_members where org_id = p_org_id and user_id = p_user_id;
end $$;

revoke execute on function public.kick_member(uuid, uuid) from public, anon;
grant execute on function public.kick_member(uuid, uuid) to authenticated;

-- Hapus workspace: hanya owner/creator; cascade hapus semua data org
-- (FK on delete cascade sudah ada di semua tabel org).
create or replace function public.delete_workspace(p_org_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_myrole text;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  select role into v_myrole from org_members
  where org_id = p_org_id and user_id = v_uid;
  if v_myrole is distinct from 'owner' then
    raise exception 'NOT_OWNER';
  end if;
  delete from organizations where id = p_org_id;
end $$;

revoke execute on function public.delete_workspace(uuid) from public, anon;
grant execute on function public.delete_workspace(uuid) to authenticated;
