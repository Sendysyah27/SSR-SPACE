-- ========== migration_33_security_policies_p3.sql ==========
-- SSR SPACE migration 33: lanjutan patch keamanan P2/P3 (audit 2026-11-25).
-- Jalankan di Supabase Dashboard -> SQL Editor (sekali; idempotent)
-- SETELAH migration_32.
--
-- Menutup 2 temuan:
-- [P2-4] join_org_by_invite tanpa rate-limit (brute force token) + pesan
--        yang membedakan invalid/expired/exhausted. Fix: RPC baru
--        join_org_by_invite_v2 yang mengembalikan KODE (bukan raise) plus
--        tabel public.join_attempts (maks 10 percobaan / 10 menit / user).
--        RPC lama dibiarkan UTUH — app versi lama masih memakainya.
-- [P2-8] fungsi trigger enforce_member_quota/enforce_auto_quota masih
--        dapat dieksekusi PUBLIC. Fix: revoke dari public, anon, authenticated.

-- ------------------------------------------------------------
-- [P2-4] join_attempts: jejak percobaan join. RPC-only: tanpa policy +
-- cabut grant -> client (anon/authenticated) tak bisa baca/tulis; hanya
-- fungsi SECURITY DEFINER yang menulis. Baris ikut COMMIT karena v2 tak
-- lagi raise (itulah inti desain rate-limit ini).
-- ------------------------------------------------------------
create table if not exists public.join_attempts (
  user_id uuid not null,
  attempted_at timestamptz not null default now()
);

create index if not exists join_attempts_user_idx
  on public.join_attempts (user_id, attempted_at);

alter table public.join_attempts enable row level security;

revoke all on table public.join_attempts from public, anon, authenticated;

-- ------------------------------------------------------------
-- [P2-4] join_org_by_invite_v2: logika resolusi SAMA dgn
-- join_org_by_invite, tapi mengembalikan jsonb {code, org_id} untuk
-- hasil normal (ok|invalid|expired|exhausted|already_member|rate_limited).
-- ------------------------------------------------------------
create or replace function public.join_org_by_invite_v2(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  inv record;
  v_hash text;
  v_org uuid;
  v_attempts int;
begin
  -- Grant hanya authenticated; ini jaring pengaman agar tak ada raw
  -- exception (client memetakannya ke "masuk dulu").
  if v_uid is null then
    return jsonb_build_object('code', 'invalid', 'org_id', null);
  end if;

  -- Rate limit: maks 10 percobaan / 10 menit / user.
  select count(*) into v_attempts
  from join_attempts
  where user_id = v_uid
    and attempted_at > now() - interval '10 minutes';
  if v_attempts >= 10 then
    return jsonb_build_object('code', 'rate_limited', 'org_id', null);
  end if;

  -- Baris attempt TIDAK rollback (fungsi tak lagi raise) — itu memang
  -- tujuannya: percobaan gagal pun tetap terhitung.
  insert into join_attempts (user_id) values (v_uid);

  -- upper() = sama dgn hashInviteToken() client (token selalu uppercase).
  v_hash := encode(
    sha256(convert_to(upper(trim(both from p_token)), 'UTF8')),
    'hex'
  );

  select * into inv
  from org_invites
  where token_hash = v_hash
  limit 1;

  if not found or inv.revoked then
    return jsonb_build_object('code', 'invalid', 'org_id', null);
  end if;
  if inv.expires_at < now() then
    return jsonb_build_object('code', 'expired', 'org_id', null);
  end if;

  -- Idempoten: sudah member -> sukses (kode already_member) tanpa
  -- menyentuh used_count.
  select org_id into v_org
  from org_members
  where org_id = inv.org_id and user_id = v_uid;
  if found then
    return jsonb_build_object('code', 'already_member', 'org_id', v_org);
  end if;

  if inv.used_count >= inv.max_uses then
    return jsonb_build_object('code', 'exhausted', 'org_id', null);
  end if;

  -- Reservasi slot atomik DULU (gerbang sebenarnya). Karena v2 tak lagi
  -- raise, urutan ini mencegah membership ter-commit saat kalah lomba
  -- pada slot terakhir (update 0 baris -> exhausted, tanpa insert).
  update org_invites
  set used_count = used_count + 1
  where id = inv.id
    and not revoked
    and used_count < max_uses
    and expires_at > now();
  if not found then
    return jsonb_build_object('code', 'exhausted', 'org_id', null);
  end if;

  insert into org_members(org_id, user_id, role)
  values (inv.org_id, v_uid, inv.role);

  return jsonb_build_object('code', 'ok', 'org_id', inv.org_id);
end $$;

revoke execute on function public.join_org_by_invite_v2(text) from public, anon;
grant execute on function public.join_org_by_invite_v2(text) to authenticated;

-- ------------------------------------------------------------
-- [P2-8] trigger quota: cabut EXECUTE dari client. Trigger tetap menembak
-- (dijalankan sistem), hanya eksekusi langsung client yang ditutup.
-- ------------------------------------------------------------
revoke all on function public.enforce_member_quota() from public, anon, authenticated;
revoke all on function public.enforce_auto_quota() from public, anon, authenticated;
