-- SSR SPACE migration 12: fix join workspace (2 temuan test suite RLS)
-- Jalankan di Supabase Dashboard → SQL Editor SETELAH migration_11.
--
-- [1] P0 — bikin workspace baru gagal sejak migration_07.
--     Gejala: insert organizations OK, insert org_members → 42501
--     "new row violates row-level security policy" (user lihat
--     "Gagal membuat workspace. Periksa nama dan koneksi.").
--     Akar: policy "join own org" cek `exists (select from organizations ...)`
--     → subquery kena RLS "member read org" (butuh sudah member) → chicken-and-egg.
--     Fix: helper SECURITY DEFINER is_org_creator baca created_by tanpa kena RLS.
--     P0 lama TETAP tertutup: attacker hanya bisa join org yang dia sendiri buat.
--
-- [2] Minor — join_org_by_invite: cek INVITE_EXHAUSTED jalan SEBELUM cek
--     "sudah member" → re-join member yang sudah masuk selalu error,
--     padahal fungsi bermaksud idempoten (lihat komentar di migration_10).
--     Fix: cek "sudah member → return" didorong ke atas, sebelum EXHAUSTED.
--     Keamanan tetap: non-member tak pernah lolos tanpa slot (increment atomik).

-- ============================================================
-- [1] is_org_creator + policy "join own org" yang baru
-- ============================================================
create or replace function public.is_org_creator(p_org_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from organizations
    where id = p_org_id
      and created_by = auth.uid()
  );
$$;

revoke execute on function public.is_org_creator(uuid) from public, anon;
grant execute on function public.is_org_creator(uuid) to authenticated;

drop policy if exists "join own org" on org_members;
create policy "join own org" on org_members
  for insert to authenticated
  with check (
    (
      user_id = auth.uid()
      and public.is_org_creator(org_id)
    )
    or public.is_org_admin(org_id)
  );

-- ============================================================
-- [2] join_org_by_invite — urutan cek: idempoten sebelum EXHAUSTED
-- ============================================================
create or replace function public.join_org_by_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  inv record;
  v_hash text;
  v_org uuid;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  -- upper() = sama dgn hashInviteToken() client (token selalu uppercase)
  v_hash := encode(
    sha256(convert_to(upper(trim(both from p_token)), 'UTF8')),
    'hex'
  );

  select * into inv
  from org_invites
  where token_hash = v_hash
  limit 1;

  if not found or inv.revoked then
    raise exception 'INVITE_INVALID';
  end if;
  if inv.expires_at < now() then
    raise exception 'INVITE_EXPIRED';
  end if;

  -- Idempoten: sudah member → sukses tanpa menyentuh used_count.
  -- (Sebelum fix: dicek SETELAH EXHAUSTED → re-join selalu error.)
  select org_id into v_org
  from org_members
  where org_id = inv.org_id and user_id = v_uid;
  if found then
    return v_org;
  end if;

  if inv.used_count >= inv.max_uses then
    raise exception 'INVITE_EXHAUSTED';
  end if;

  insert into org_members(org_id, user_id, role)
  values (inv.org_id, v_uid, inv.role);

  -- Increment = gerbang atomik (bukan sekadar counter).
  update org_invites
  set used_count = used_count + 1
  where id = inv.id
    and not revoked
    and used_count < max_uses
    and expires_at > now();

  if not found then
    raise exception 'INVITE_EXHAUSTED';
  end if;

  return inv.org_id;
end $$;

grant execute on function public.join_org_by_invite(text) to authenticated;
