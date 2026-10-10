-- SSR SPACE baseline skema (squash Batch 7 Sprint).
-- Gabungan verbatim migration_02..19 sesuai urutan (fresh install cukup:
-- setup.sql -> schema.sql -> file ini). Riwayat per-file tetap di git.
-- DB produksi yang sudah jalan 02..19 TAK PERLU apa-apa.
-- Satu-satunya adaptasi vs file asli: blok pg_cron (migration_13)
-- dibuat guarded seperti migration_18, supaya lolos CI/lokal tanpa ext
-- (di Supabase asli jalan normal). DB produksi tak berubah perilaku.

-- ========== migration_02_org_policies.sql ==========
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

-- ========== migration_03_budgets.sql ==========
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

-- ========== migration_04_subscriptions.sql ==========
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

-- ========== migration_05_tx_codes.sql ==========
-- SSR SPACE migration 05: kode transaksi TX-000001 per workspace
alter table transactions add column if not exists code text;

create table if not exists tx_sequences (
  org_id uuid primary key references organizations(id) on delete cascade,
  last_number int not null default 0
);

alter table tx_sequences enable row level security;

create or replace function mint_tx_code(p_org_id uuid)
returns text language plpgsql security definer as $$
declare n int;
begin
  if not exists (
    select 1 from org_members m
    where m.org_id = p_org_id and m.user_id = auth.uid()
  ) then
    raise exception 'not a member of workspace';
  end if;

  insert into tx_sequences(org_id, last_number)
    values (p_org_id, 0) on conflict (org_id) do nothing;
  select last_number + 1 into n from tx_sequences
    where org_id = p_org_id for update;
  update tx_sequences set last_number = n where org_id = p_org_id;
  return 'TX-' || lpad(n::text, 6, '0');
end $$;

grant execute on function mint_tx_code(uuid) to authenticated;

with ranked as (
  select id, row_number() over (partition by org_id order by date, created_at) as rn
  from transactions where code is null
)
update transactions t set code = 'TX-' || lpad(ranked.rn::text, 6, '0')
from ranked where t.id = ranked.id;

with mx as (select org_id, count(*) as c from transactions group by org_id)
insert into tx_sequences(org_id, last_number)
select org_id, c from mx
on conflict (org_id) do update set last_number = excluded.last_number;

-- ========== migration_06_notif_source.sql ==========
-- SSR SPACE migration 06: sumber pelacakan notifikasi otomatis
alter table transactions add column if not exists source_package text;
alter table transactions add column if not exists source_hash text;

create unique index if not exists unique_tx_hash
  on transactions(org_id, source_hash) where source_hash is not null;

-- ========== migration_07_security.sql ==========
-- SSR SPACE migration 07: perketat join workspace + mint_tx_code wajib member
-- Jalankan di Supabase Dashboard -> SQL Editor (sekali saja).
-- CATATAN: jangan bikin policy SELECT org_members yang query org_members lagi
-- (RLS recursion). Helper is_org_admin dipakai utk cek owner/admin.

alter table organizations add column if not exists created_by uuid;

-- backfill: owner pertama dianggap pembuat
update organizations o
set created_by = (
  select m.user_id from org_members m
  where m.org_id = o.id and m.role = 'owner'
  limit 1
)
where o.created_by is null;

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

drop policy if exists "auth create org" on organizations;
create policy "auth create org" on organizations
  for insert to authenticated
  with check (created_by = auth.uid());

-- Self-join hanya untuk org yang user buat; owner/admin boleh tambah member lain.
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

-- Hanya baca keanggotaan sendiri. JANGAN tambah policy SELECT yang subquery
-- ke org_members sendiri → infinite recursion (lihat migration_08).
drop policy if exists "member read org_members" on org_members;
drop policy if exists "own memberships" on org_members;
create policy "own memberships" on org_members
  for select to authenticated
  using (user_id = auth.uid());

create or replace function mint_tx_code(p_org_id uuid)
returns text language plpgsql security definer as $$
declare n int;
begin
  if not exists (
    select 1 from org_members m
    where m.org_id = p_org_id and m.user_id = auth.uid()
  ) then
    raise exception 'not a member of workspace';
  end if;

  insert into tx_sequences(org_id, last_number)
    values (p_org_id, 0) on conflict (org_id) do nothing;
  select last_number + 1 into n from tx_sequences
    where org_id = p_org_id for update;
  update tx_sequences set last_number = n where org_id = p_org_id;
  return 'TX-' || lpad(n::text, 6, '0');
end $$;

grant execute on function mint_tx_code(uuid) to authenticated;

-- ========== migration_08_fix_rls_recursion.sql ==========
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

-- ========== migration_09_wallet_balance.sql ==========
-- migration_09: view saldo per dompet (Sprint A2)
-- Jalankan di Supabase Dashboard → SQL Editor SEBELUM pakai APK baru.

create or replace view public.wallet_balance
with (security_invoker = true) as
select
  w.org_id,
  w.id as wallet_id,
  coalesce(sum(case
    when t.type = 'in'       and t.wallet_id = w.id    then  t.amount
    when t.type = 'out'      and t.wallet_id = w.id    then -t.amount
    when t.type = 'transfer' and t.wallet_id = w.id    then -t.amount
    when t.type = 'transfer' and t.to_wallet_id = w.id then  t.amount
    else 0 end), 0)::numeric as balance
from public.wallets w
left join public.transactions t
  on t.org_id = w.org_id
 and (t.wallet_id = w.id or t.to_wallet_id = w.id)
group by w.org_id, w.id;

grant select on public.wallet_balance to authenticated;

-- ========== migration_10_org_invites.sql ==========
-- SSR SPACE migration 10: invite workspace (token hash, sekali pakai)
-- Jalankan di Supabase Dashboard → SQL Editor SETELAH migration_09.

create table if not exists org_invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  role text not null default 'member' check (role in ('member', 'admin')),
  token_hash text not null unique,
  created_by uuid not null,
  expires_at timestamptz not null default (now() + interval '7 days'),
  max_uses int not null default 1,
  used_count int not null default 0,
  revoked boolean not null default false,
  created_at timestamptz not null default now()
);

alter table org_invites enable row level security;

-- SELECT: hanya admin/org. is_org_admin = SECURITY DEFINER (migration_08),
-- jangan subquery org_members di sini (aturan anti-recursion AGENTS.md).
drop policy if exists "admin read org_invites" on org_invites;
create policy "admin read org_invites" on org_invites
  for select using (public.is_org_admin(org_id));

drop policy if exists "admin create org_invites" on org_invites;
create policy "admin create org_invites" on org_invites
  for insert with check (
    public.is_org_admin(org_id) and created_by = auth.uid()
  );

drop policy if exists "admin update org_invites" on org_invites;
create policy "admin update org_invites" on org_invites
  for update using (public.is_org_admin(org_id));

-- Join HANYA lewat RPC. sha256 bawaan Postgres (PG11+), tanpa pgcrypto.
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
  if inv.used_count >= inv.max_uses then
    raise exception 'INVITE_EXHAUSTED';
  end if;

  -- idempotent: sudah member → sukses tanpa tambah used_count
  select org_id into v_org
  from org_members
  where org_id = inv.org_id and user_id = v_uid;
  if found then
    return v_org;
  end if;

  insert into org_members(org_id, user_id, role)
  values (inv.org_id, v_uid, inv.role);

  -- Increment = gerbang atomik (bukan sekadar counter).
  -- Dua join bersamaan pada slot terakhir: baris invite dikunci transaksi,
  -- yang kedua menunggu lalu WHERE gagal → INVITE_EXHAUSTED,
  -- dan insert member di atas ikut ter-rollback.
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

revoke execute on function public.join_org_by_invite(text) from public, anon;
grant execute on function public.join_org_by_invite(text) to authenticated;

-- ========== migration_11_hardening.sql ==========
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

-- ========== migration_12_join_fixes.sql ==========
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

-- ========== migration_13_retention.sql ==========
-- SSR SPACE migration 13: retention otomatis pg_cron (Fase 3 F3-d / backlog D6)
-- Jalankan di Supabase Dashboard → SQL Editor SETELAH migration_12.
--
-- Free plan Supabase: pg_cron tersedia (alternatif: aktifkan via
-- Dashboard → Database → Extensions bila create extension ditolak).
-- Job dijalankan sebagai role penjadwal (postgres) → lewati RLS, aman utk delete.
--
-- Retention:
--   client_errors      30 hari  (log error jangka pendek)
--   audit_logs        180 hari  (jejak keamanan cukup 6 bulan, hemat DB)
--   cron.job_run_details 14 hari (mencegah tabel pg_cron membengkak —
--                                 peringatan resmi Supabase soal gagal upgrade)

DO $$ BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'SKIP pg_cron ext (bukan Supabase)';
END $$;

-- Idempotent: bila job sudah ada, unschedule dulu lalu jadwalkan ulang.
do $$
declare v_id bigint;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'SKIP retention cron (bukan Supabase)';
    return;
  end if;
  select jobid into v_id from cron.job where jobname = 'ssr_client_errors_retention';
  if v_id is not null then perform cron.unschedule(v_id); end if;
  perform cron.schedule(
    'ssr_client_errors_retention', '17 3 * * *',
    $q$delete from client_errors where created_at < now() - interval '30 days'$q$
  );
end $$;

do $$
declare v_id bigint;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'SKIP retention cron (bukan Supabase)';
    return;
  end if;
  select jobid into v_id from cron.job where jobname = 'ssr_audit_logs_retention';
  if v_id is not null then perform cron.unschedule(v_id); end if;
  perform cron.schedule(
    'ssr_audit_logs_retention', '23 3 * * *',
    $q$delete from audit_logs where created_at < now() - interval '180 days'$q$
  );
end $$;

do $$
declare v_id bigint;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'SKIP retention cron (bukan Supabase)';
    return;
  end if;
  select jobid into v_id from cron.job where jobname = 'ssr_cron_run_details_retention';
  if v_id is not null then perform cron.unschedule(v_id); end if;
  perform cron.schedule(
    'ssr_cron_run_details_retention', '29 3 * * *',
    $q$delete from cron.job_run_details where start_time < now() - interval '14 days'$q$
  );
end $$;

-- ========== migration_14_workspace_admin.sql ==========
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

-- ========== migration_15_we_space.sql ==========
-- SSR SPACE migration 15: We Space (mode bebas/bendahara + audit manual/kick).
-- Jalankan di Supabase Dashboard -> SQL Editor SETELAH migration_14.

alter table organizations
  add column if not exists space_mode text not null default 'bebas';
alter table organizations drop constraint if exists organizations_space_mode_check;
alter table organizations
  add constraint organizations_space_mode_check check (space_mode in ('bebas', 'bendahara'));

-- Helper tulis: satu-satunya pembaca org_members di jalur tulis (anti-recursion).
-- Policy RLS di bawah TIDAK subquery org_members langsung (aturan AGENTS.md).
create or replace function public.can_write_space(p_org_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from org_members m
    join organizations o on o.id = m.org_id
    where m.org_id = p_org_id
      and m.user_id = auth.uid()
      and (o.space_mode = 'bebas' or m.role in ('owner', 'admin'))
  );
$$;

revoke execute on function public.can_write_space(uuid) from public, anon;
grant execute on function public.can_write_space(uuid) to authenticated;

-- Pecah policy tulis wallets: SELECT tetap member-read, tulis via helper.
drop policy if exists "member wallets" on wallets;
drop policy if exists "member read wallets" on wallets;
create policy "member read wallets" on wallets
  for select using (exists (select 1 from org_members m where m.org_id = wallets.org_id and m.user_id = auth.uid()));
drop policy if exists "space write wallets" on wallets;
create policy "space write wallets" on wallets
  for insert with check (public.can_write_space(org_id));
drop policy if exists "space update wallets" on wallets;
create policy "space update wallets" on wallets
  for update using (public.can_write_space(org_id)) with check (public.can_write_space(org_id));
drop policy if exists "space delete wallets" on wallets;
create policy "space delete wallets" on wallets
  for delete using (public.can_write_space(org_id));

-- Pecah policy tulis transactions: pola sama.
drop policy if exists "member tx" on transactions;
drop policy if exists "member read tx" on transactions;
create policy "member read tx" on transactions
  for select using (exists (select 1 from org_members m where m.org_id = transactions.org_id and m.user_id = auth.uid()));
drop policy if exists "space write tx" on transactions;
create policy "space write tx" on transactions
  for insert with check (public.can_write_space(org_id));
drop policy if exists "space update tx" on transactions;
create policy "space update tx" on transactions
  for update using (public.can_write_space(org_id)) with check (public.can_write_space(org_id));
drop policy if exists "space delete tx" on transactions;
create policy "space delete tx" on transactions
  for delete using (public.can_write_space(org_id));

-- Ganti mode: hanya owner/admin, via RPC saja (tanpa policy UPDATE organizations).
create or replace function public.set_space_mode(p_org_id uuid, p_mode text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_myrole text;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_mode not in ('bebas', 'bendahara') then
    raise exception 'BAD_MODE';
  end if;
  select role into v_myrole from org_members
  where org_id = p_org_id and user_id = auth.uid();
  if v_myrole is null or v_myrole not in ('owner', 'admin') then
    raise exception 'NOT_ADMIN';
  end if;
  update organizations set space_mode = p_mode where id = p_org_id;
  insert into audit_logs (org_id, actor_user_id, event, meta)
  values (p_org_id, auth.uid(), 'space_mode_change', jsonb_build_object('mode', p_mode));
end $$;

revoke execute on function public.set_space_mode(uuid, text) from public, anon;
grant execute on function public.set_space_mode(uuid, text) to authenticated;

-- Audit insert manual (source_package null); auto tetap trigger lama.
create or replace function public.log_manual_tx_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.source_package is not null then
    return new;
  end if;
  insert into audit_logs (org_id, actor_user_id, event, meta)
  values (
    new.org_id,
    auth.uid(),
    'tx_manual_insert',
    jsonb_build_object(
      'tx_id', new.id,
      'amount', new.amount,
      'type', new.type,
      'category', new.category
    )
  );
  return new;
end $$;

drop trigger if exists trg_audit_manual_tx on transactions;
create trigger trg_audit_manual_tx
  after insert on transactions
  for each row
  execute function public.log_manual_tx_insert();

-- Audit kick: salin utuh function migration_14 + insert audit sebelum delete.
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
  insert into audit_logs (org_id, actor_user_id, event, meta)
  values (p_org_id, v_uid, 'member_kick', jsonb_build_object('target', p_user_id));
  delete from org_members where org_id = p_org_id and user_id = p_user_id;
end $$;

-- Catatan jujur: delete_workspace TANPA audit — FK cascade menghapus audit_logs
-- org tersebut, jadi baris auditnya ikut hilang. Jangan tambah insert mati di sini.

revoke execute on function public.kick_member(uuid, uuid) from public, anon;
grant execute on function public.kick_member(uuid, uuid) to authenticated;

-- ========== migration_16_budget_alerts.sql ==========
-- SSR SPACE migration 16: budget alerts real-time via trigger.
-- Jalankan di Supabase Dashboard → SQL Editor SETELAH migration_15.
-- Spec: docs/superpowers/specs/2026-10-06-budget-alerts-design.md §3.
-- Keputusan kunci: warn_pct default 80 (check 1-100); trigger AFTER INSERT
-- WHEN (NEW.type='out') fail-open; agregasi grup lapis-atas, null → 'Lainnya';
-- RLS member-read tanpa write; tanpa backfill.

-- 1. Ambang custom per budget.
alter table budgets
  add column if not exists warn_pct int not null default 80;
alter table budgets drop constraint if exists budgets_warn_pct_check;
alter table budgets
  add constraint budgets_warn_pct_check check (warn_pct between 1 and 100);

-- 2. Fakta alert (org, bulan, kategori grup-atas, level).
create table if not exists budget_alerts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  month text not null,
  category text not null,
  level text not null check (level in ('warn', 'breach')),
  spent numeric not null,
  limit_amount numeric not null,
  created_at timestamptz default now(),
  unique (org_id, month, category, level)
);

alter table budget_alerts enable row level security;

-- Member-read saja; TANPA policy INSERT/UPDATE/DELETE (deny total).
-- Subquery ke org_members dari tabel LAIN aman (bukan policy di org_members).
drop policy if exists "member read budget_alerts" on budget_alerts;
create policy "member read budget_alerts" on budget_alerts
  for select using (
    exists (
      select 1 from org_members m
      where m.org_id = budget_alerts.org_id and m.user_id = auth.uid()
    )
  );

create index if not exists budget_alerts_org_month_idx
  on budget_alerts (org_id, month);

-- 3. Trigger: cek ambang tiap insert belanja, fail-open.
create or replace function public.check_budget_alert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month text := substring(NEW.date::text, 1, 7);
  v_top text := coalesce(nullif(split_part(NEW.category, ' > ', 1), ''), 'Lainnya');
  v_limit numeric;
  v_warn int;
  v_spent numeric;
begin
  select limit_amount, warn_pct into v_limit, v_warn
  from budgets
  where org_id = NEW.org_id and month = v_month and category = v_top;
  if not found then
    return NEW;
  end if;

  select coalesce(sum(amount), 0) into v_spent
  from transactions
  where org_id = NEW.org_id
    and type = 'out'
    and substring(date::text, 1, 7) = v_month
    and coalesce(nullif(split_part(category, ' > ', 1), ''), 'Lainnya') = v_top;

  v_warn := coalesce(v_warn, 80);
  if v_spent >= v_limit * v_warn / 100 then
    if not exists (
      select 1 from budget_alerts
      where org_id = NEW.org_id and month = v_month and category = v_top and level = 'warn'
    ) then
      insert into budget_alerts (org_id, month, category, level, spent, limit_amount)
      values (NEW.org_id, v_month, v_top, 'warn', v_spent, v_limit);
    end if;
  end if;

  if v_spent >= v_limit then
    if not exists (
      select 1 from budget_alerts
      where org_id = NEW.org_id and month = v_month and category = v_top and level = 'breach'
    ) then
      insert into budget_alerts (org_id, month, category, level, spent, limit_amount)
      values (NEW.org_id, v_month, v_top, 'breach', v_spent, v_limit);
    end if;
  end if;

  return NEW;
exception when others then
  return NEW;
end $$;

drop trigger if exists trg_check_budget_alert on transactions;
create trigger trg_check_budget_alert
  after insert on transactions
  for each row
  when (NEW.type = 'out')
  execute function public.check_budget_alert();

-- ========== migration_17_quotas.sql ==========
-- SSR SPACE migration 17: kuota paket ditegakkan SERVER (Batch 3 Sprint).
-- Paket Gratis: workspace 2/user, anggota 3/org, auto-track 150/org/bulan.
-- Pro (organizations.plan = 'pro'): bebas. Klien tetap cek dulu untuk UX,
-- tapi server yang memutuskan: trigger menolak dengan 'QUOTA_EXCEEDED',
-- RPC check_quota memberi angka jujur untuk UI.
--
-- Kompatibel suite RLS: fixture tak pernah menyentuh batas
-- (org A maks 2 anggota saat insert ke-3; auto/bulan < 20).

-- Helper paket org (definer: bisa dibaca trigger/RPC tanpa self-RLS).
create or replace function public.org_plan(p_org_id uuid)
returns text
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select plan from organizations where id = p_org_id), 'free');
$$;

-- Kebenaran kuota untuk UI: {allowed, used, limit, plan}.
-- kind: 'auto' | 'members' | 'workspaces'. Kind asing = fail-closed.
create or replace function public.check_quota(p_org_id uuid, p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan text := 'free';
  v_used int := 0;
  v_limit int := 0;
  v_pro int := 0;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_kind not in ('auto', 'members', 'workspaces') then
    raise exception 'QUOTA_UNKNOWN_KIND';
  end if;

  if p_kind = 'workspaces' then
    -- Milik user, bukan org: hitung keanggotaan pemanggil.
    select count(*) into v_used
    from org_members where user_id = auth.uid();
    v_limit := 2;
    select count(*) into v_pro
    from organizations o
    join org_members m on m.org_id = o.id
    where m.user_id = auth.uid() and o.plan = 'pro';
    return jsonb_build_object(
      'allowed', v_used < v_limit or v_pro > 0,
      'used', v_used, 'limit', v_limit, 'plan',
      case when v_pro > 0 then 'pro' else 'free' end);
  end if;

  -- 'auto'/'members': pemanggil wajib member org tersebut.
  if not exists (select 1 from org_members
                 where org_id = p_org_id and user_id = auth.uid()) then
    raise exception 'NOT_MEMBER';
  end if;
  v_plan := public.org_plan(p_org_id);

  if p_kind = 'auto' then
    v_limit := 150;
    select count(*) into v_used
    from transactions
    where org_id = p_org_id
      and source_package is not null
      and date >= date_trunc('month', current_date)::date;
  else
    v_limit := 3;
    select count(*) into v_used
    from org_members where org_id = p_org_id;
  end if;

  return jsonb_build_object(
    'allowed', v_plan <> 'free' or v_used < v_limit,
    'used', v_used, 'limit', v_limit, 'plan', v_plan);
end $$;

revoke all on function public.org_plan(uuid) from public, anon;
grant execute on function public.org_plan(uuid) to authenticated;
revoke all on function public.check_quota(uuid, text) from public, anon;
grant execute on function public.check_quota(uuid, text) to authenticated;

-- Penegakan: auto-track bulanan (insert manual bebas, pola migration_11).
create or replace function public.enforce_auto_quota()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_used int;
begin
  if new.source_package is null then
    return new;
  end if;
  if public.org_plan(new.org_id) <> 'free' then
    return new;
  end if;
  select count(*) into v_used
  from transactions
  where org_id = new.org_id
    and source_package is not null
    and date >= date_trunc('month', current_date)::date;
  if v_used >= 150 then
    raise exception 'QUOTA_EXCEEDED';
  end if;
  return new;
end $$;

drop trigger if exists trg_auto_quota on transactions;
create trigger trg_auto_quota
  before insert on transactions
  for each row
  execute function public.enforce_auto_quota();

-- Penegakan: anggota per org (owner pertama selalu lolos: count 0).
create or replace function public.enforce_member_quota()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_used int;
begin
  if public.org_plan(new.org_id) <> 'free' then
    return new;
  end if;
  select count(*) into v_used
  from org_members where org_id = new.org_id;
  if v_used >= 3 then
    raise exception 'QUOTA_EXCEEDED';
  end if;
  return new;
end $$;

drop trigger if exists trg_member_quota on org_members;
create trigger trg_member_quota
  before insert on org_members
  for each row
  execute function public.enforce_member_quota();

-- Penegakan: workspace per user (pro = ada 1 org pro yang diikuti).
create or replace function public.enforce_workspace_quota()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_used int;
  v_pro int;
begin
  select count(*) into v_used
  from org_members where user_id = new.created_by;
  if v_used < 2 then
    return new;
  end if;
  select count(*) into v_pro
  from organizations o
  join org_members m on m.org_id = o.id
  where m.user_id = new.created_by and o.plan = 'pro';
  if v_pro > 0 then
    return new;
  end if;
  raise exception 'QUOTA_EXCEEDED';
end $$;

drop trigger if exists trg_workspace_quota on organizations;
create trigger trg_workspace_quota
  before insert on organizations
  for each row
  execute function public.enforce_workspace_quota();

-- ========== migration_18_scale.sql ==========
-- SSR SPACE migration 18: skala baca + heartbeat anti-pause (Batch 5 Sprint).
-- A. month_mix: agregat sebulan per (jenis, kategori) untuk matematika
--    Beranda/Laporan yang eksak di skala berapa pun (ganti fold list 200).
-- B. heartbeat: jejak aktivitas harian anti-pause project free-tier
--    (pause setelah 7 hari tanpa API/DB activity).
--    3 lapis: pg_cron harian (guarded, lolos CI tanpa ext) + RPC touch
--    dari app (max 1/hari/device) + workflow heartbeat.yml tiap 3 hari.

-- ============ A. month_mix ============
-- p_month 'YYYY-MM'; p_wallet null = semua (transfer ikut bila salah satu
-- kakinya cocok, selaras filterByWallet klien).
create or replace function public.month_mix(
  p_org_id uuid, p_month text, p_wallet uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start date;
  v_end date;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if not exists (select 1 from org_members
                 where org_id = p_org_id and user_id = auth.uid()) then
    raise exception 'NOT_MEMBER';
  end if;
  begin
    v_start := to_date(p_month || '-01', 'YYYY-MM-DD');
  exception when others then
    raise exception 'MIX_BAD_MONTH';
  end;
  v_end := (date_trunc('month', v_start) + interval '1 month')::date;
  return jsonb_build_object(
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object('t', t, 'c', c, 's', s, 'n', n))
      from (
        select type as t,
               coalesce(category, '') as c,
               sum(amount)::double precision as s,
               count(*)::int as n
        from transactions
        where org_id = p_org_id
          and date >= v_start and date < v_end
          and (p_wallet is null
               or wallet_id = p_wallet or to_wallet_id = p_wallet)
        group by type, category
      ) agg), '[]'::jsonb),
    'total_n', coalesce((
      select sum(cnt) from (
        select count(*)::int as cnt
        from transactions
        where org_id = p_org_id
          and date >= v_start and date < v_end
          and (p_wallet is null
               or wallet_id = p_wallet or to_wallet_id = p_wallet)
      ) c2), 0));
end $$;

revoke all on function public.month_mix(uuid, text, uuid)
  from public, anon;
grant execute on function public.month_mix(uuid, text, uuid)
  to authenticated;

-- ============ B. heartbeat ============
create table if not exists heartbeat (
  id uuid primary key default gen_random_uuid(),
  pinged_at timestamptz not null default now(),
  source text not null default 'app',
  user_id uuid
);

alter table heartbeat enable row level security;
-- Tanpa policy client: tulis/baca HANYA via RPC di bawah (deny total).

-- Sentuh dari app (max 1/hari ditegakkan klien via prefs; server prune).
create or replace function public.touch_heartbeat(p_source text default 'app')
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  insert into heartbeat (source, user_id)
  values (substr(coalesce(p_source, 'app'), 1, 24), auth.uid());
  delete from heartbeat where pinged_at < v_now - interval '30 days';
  return v_now;
end $$;

revoke all on function public.touch_heartbeat(text) from public, anon;
grant execute on function public.touch_heartbeat(text) to authenticated;

-- pg_cron harian: guarded (CI/lokal tanpa ext = lewati diam-diam).
-- Job sebagai postgres → lewati RLS, tulis langsung.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job
      where jobname = 'ssr_heartbeat_daily';
    perform cron.schedule(
      'ssr_heartbeat_daily', '11 3 * * *',
      $q$insert into heartbeat (source) values ('pg-cron')$q$
    );
  end if;
end $$;

-- ========== migration_19_realtime.sql ==========
-- SSR SPACE migration 19: realtime sync (Batch 6 Sprint).
-- Event UPDATE/DELETE butuh REPLICA IDENTITY FULL agar payload
-- baris lama lengkap (batasan Postgres, bukan Supabase).
-- Publication guarded: CI/lokal tanpa publication supabase_realtime
-- = lewati diam-diam (di Supabase asli selalu ada).

alter table transactions replica identity full;
alter table org_members replica identity full;
alter table wallets replica identity full;
alter table budgets replica identity full;

do $$
declare
  t text;
begin
  if not exists (select 1 from pg_publication
                 where pubname = 'supabase_realtime') then
    raise notice 'SKIP realtime publication (bukan Supabase)';
    return;
  end if;
  foreach t in array array[
    'transactions', 'org_members', 'wallets', 'budgets'
  ] loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime'
                     and tablename = t::name) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end $$;
