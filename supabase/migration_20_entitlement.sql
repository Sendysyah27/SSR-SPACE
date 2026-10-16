-- ========== migration_20_entitlement.sql ==========
-- SSR SPACE migration 20: entitlement + limit (Fase 1 Ollo-adapt).
-- Spec: docs/superpowers/specs/2026-10-16-ollo-fase1-entitlement-design.md §5.
-- Jalankan di Supabase Dashboard → SQL Editor SETELAH migration_19
-- (fresh install: schema.sql + migration_squashed.sql + file ini).
--
-- Isi: plan_expires_at + 3 tabel RPC-only + org_plan() diperluas
-- (expiry + VIP-owner) + RPC plan_status/redeem_vip_code/record_ai_usage +
-- check_quota kind wallets|budgets|ai + trigger wallet/budget + retention ai_usage.
-- Idempotent: boleh dijalankan ulang (IF NOT EXISTS / OR REPLACE / DROP+CREATE).
--
-- Contoh buat kode VIP (owner via SQL Editor; kode asli tak pernah disimpan):
--   insert into vip_codes (code_hash, duration_days, max_uses, note)
--   values (
--     encode(sha256(convert_to(upper(trim(both from 'SSR-VIP-2026')), 'UTF8')), 'hex'),
--     30, 5, 'promo launch'
--   );
-- duration_days null = permanen.

-- 1. Expiry plan org (null = tanpa kedaluwarsa; siap Midtrans settlement).
alter table organizations
  add column if not exists plan_expires_at timestamptz;

-- 2. Tabel baru — ketiganya RPC-only: RLS aktif TANPA policy client,
--    baca/tulis langsung dari client = ditolak (pola heartbeat migration_18).
create table if not exists user_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan text not null default 'pro',
  expires_at timestamptz,
  source text not null default 'vip_code',
  source_ref text,
  granted_at timestamptz not null default now()
);

alter table user_entitlements enable row level security;

create index if not exists user_entitlements_user_idx
  on user_entitlements (user_id);

-- Guard idempotensi redeem: satu user hanya satu entitlement per kode
-- (gagalkan double-redeem konkuren di level DB, bukan sekadar SELECT-check).
create unique index if not exists user_entitlements_user_coderef_uidx
  on user_entitlements (user_id, source_ref) where source = 'vip_code';

create table if not exists vip_codes (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique,
  duration_days int check (duration_days is null or duration_days > 0),
  max_uses int not null default 1 check (max_uses >= 1),
  used_count int not null default 0 check (used_count >= 0),
  note text,
  created_at timestamptz not null default now()
);

alter table vip_codes enable row level security;

create table if not exists ai_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  org_id uuid not null references organizations(id) on delete cascade,
  kind text not null default 'chat',
  created_at timestamptz not null default now()
);

alter table ai_usage enable row level security;

create index if not exists ai_usage_user_org_created_idx
  on ai_usage (user_id, org_id, created_at);

-- 3. org_plan() diperluas: pro bila org-pro-belum-expired ATAU ada owner
--    (role='owner', bisa >1) dengan entitlement aktif. Selain itu 'free'.
--    Org tak dikenal = 'free' (kompatibel perilaku lama via coalesce).
create or replace function public.org_plan(p_org_id uuid)
returns text
language sql
security definer
set search_path = public
as $$
  select case
    when exists (
      select 1 from organizations o
      where o.id = p_org_id
        and o.plan = 'pro'
        and (o.plan_expires_at is null or o.plan_expires_at > now())
    ) then 'pro'
    when exists (
      select 1 from org_members m
      join user_entitlements e on e.user_id = m.user_id
      where m.org_id = p_org_id
        and m.role = 'owner'
        and (e.expires_at is null or e.expires_at > now())
    ) then 'pro'
    else 'free'
  end;
$$;

revoke all on function public.org_plan(uuid) from public, anon;
grant execute on function public.org_plan(uuid) to authenticated;

-- 4a. plan_status: {plan, source org|vip|null, expires_at}. Fail-closed.
create or replace function public.plan_status(p_org_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan text;
  v_org_exp timestamptz;
  v_vip_exp timestamptz;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if not exists (select 1 from org_members
                 where org_id = p_org_id and user_id = auth.uid()) then
    raise exception 'NOT_MEMBER';
  end if;

  select o.plan_expires_at into v_org_exp
  from organizations o
  where o.id = p_org_id
    and o.plan = 'pro'
    and (o.plan_expires_at is null or o.plan_expires_at > now());
  if found then
    return jsonb_build_object(
      'plan', 'pro', 'source', 'org', 'expires_at', v_org_exp);
  end if;

  -- Entitlement aktif milik salah satu owner (permanen/null didahulukan).
  select e.expires_at into v_vip_exp
  from user_entitlements e
  join org_members m on m.user_id = e.user_id
  where m.org_id = p_org_id
    and m.role = 'owner'
    and (e.expires_at is null or e.expires_at > now())
  order by e.expires_at nulls first
  limit 1;
  if found then
    return jsonb_build_object(
      'plan', 'pro', 'source', 'vip', 'expires_at', v_vip_exp);
  end if;

  v_plan := public.org_plan(p_org_id);
  return jsonb_build_object(
    'plan', v_plan, 'source', null, 'expires_at', null);
end $$;

revoke all on function public.plan_status(uuid) from public, anon;
grant execute on function public.plan_status(uuid) to authenticated;

-- 4b. redeem_vip_code: normalisasi + hash pola invite (join_org_by_invite),
--     idempoten sebelum EXHAUSTED, increment = gerbang atomik lawan race.
create or replace function public.redeem_vip_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_hash text;
  vip record;
  ent record;
  v_exp timestamptz;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  v_hash := encode(
    sha256(convert_to(upper(trim(both from p_code)), 'UTF8')),
    'hex'
  );

  select * into vip
  from vip_codes
  where code_hash = v_hash
  limit 1;

  if not found then
    raise exception 'VIP_INVALID';
  end if;

  -- Idempoten: user+kode sama (cocok source_ref) → entitlement lama,
  -- tanpa increment (sebelum cek EXHAUSTED, pola join_org_by_invite).
  select * into ent
  from user_entitlements
  where user_id = v_uid
    and source = 'vip_code'
    and source_ref = v_hash
  limit 1;
  if found then
    return jsonb_build_object(
      'expires_at', ent.expires_at, 'duration_days', vip.duration_days);
  end if;

  if vip.used_count >= vip.max_uses then
    raise exception 'VIP_EXHAUSTED';
  end if;

  if vip.duration_days is null then
    v_exp := null;
  else
    v_exp := now() + (vip.duration_days || ' days')::interval;
  end if;

  insert into user_entitlements (user_id, plan, expires_at, source, source_ref)
  values (v_uid, 'pro', v_exp, 'vip_code', v_hash);

  -- Increment = gerbang atomik (bukan sekadar counter).
  update vip_codes
  set used_count = used_count + 1
  where id = vip.id
    and used_count < max_uses;

  if not found then
    raise exception 'VIP_EXHAUSTED';
  end if;

  return jsonb_build_object(
    'expires_at', v_exp, 'duration_days', vip.duration_days);
end $$;

revoke all on function public.redeem_vip_code(text) from public, anon;
grant execute on function public.redeem_vip_code(text) to authenticated;

-- 4c. check_quota: tambah kind wallets|budgets|ai. Bentuk return sama
--     {allowed, used, limit, plan} dengan plan dari org_plan() baru.
--     Kind asing tetap QUOTA_UNKNOWN_KIND (fail-closed).
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
  v_month text := to_char(current_date, 'YYYY-MM');
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if coalesce(p_kind, '') not in (
    'auto', 'members', 'workspaces', 'wallets', 'budgets', 'ai'
  ) then
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
    where m.user_id = auth.uid() and public.org_plan(o.id) = 'pro';
    return jsonb_build_object(
      'allowed', v_used < v_limit or v_pro > 0,
      'used', v_used, 'limit', v_limit, 'plan',
      case when v_pro > 0 then 'pro' else 'free' end);
  end if;

  -- 'auto'/'members'/'wallets'/'budgets'/'ai': pemanggil wajib member.
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
  elsif p_kind = 'members' then
    v_limit := 3;
    select count(*) into v_used
    from org_members where org_id = p_org_id;
  elsif p_kind = 'wallets' then
    v_limit := 7;
    select count(*) into v_used
    from wallets where org_id = p_org_id;
  elsif p_kind = 'budgets' then
    v_limit := 7;
    select count(*) into v_used
    from budgets where org_id = p_org_id and month = v_month;
  else
    -- 'ai': user-scoped tapi butuh p_org_id sebagai konteks workspace.
    v_limit := 30;
    select count(*) into v_used
    from ai_usage
    where org_id = p_org_id
      and user_id = auth.uid()
      and created_at >= date_trunc('month', now());
  end if;

  return jsonb_build_object(
    'allowed', v_plan <> 'free' or v_used < v_limit,
    'used', v_used, 'limit', v_limit, 'plan', v_plan);
end $$;

revoke all on function public.check_quota(uuid, text) from public, anon;
grant execute on function public.check_quota(uuid, text) to authenticated;

-- 4d. record_ai_usage: catat SETELAH panggilan AI sukses (pre-check via
--     check_quota('ai') oleh klien). Tanpa enforce limit di sini.
create or replace function public.record_ai_usage(p_org_id uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if not exists (select 1 from org_members
                 where org_id = p_org_id and user_id = auth.uid()) then
    raise exception 'NOT_MEMBER';
  end if;
  insert into ai_usage (user_id, org_id, kind)
  values (auth.uid(), p_org_id, substr(coalesce(p_kind, 'chat'), 1, 32));
end $$;

revoke all on function public.record_ai_usage(uuid, text) from public, anon;
grant execute on function public.record_ai_usage(uuid, text) to authenticated;

-- Ganti query lama o.plan='pro' → org_plan() baru (VIP-aware).
-- Trigger existing lain (auto/member) sudah panggil org_plan() → ikut otomatis.
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
  where m.user_id = new.created_by and public.org_plan(o.id) = 'pro';
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

-- 5a. wallets BEFORE INSERT: Pro lolos; else ≥7 → QUOTA_EXCEEDED.
--     Fail-open hanya untuk error tak terduga; QUOTA_EXCEEDED diteruskan.
create or replace function public.enforce_wallet_quota()
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
  from wallets where org_id = new.org_id;
  if v_used >= 7 then
    raise exception 'QUOTA_EXCEEDED';
  end if;
  return new;
exception when others then
  if sqlerrm like '%QUOTA_EXCEEDED%' then
    raise;
  end if;
  return new;
end $$;

drop trigger if exists trg_wallet_quota on wallets;
create trigger trg_wallet_quota
  before insert on wallets
  for each row
  execute function public.enforce_wallet_quota();

-- 5b. budgets BEFORE INSERT: Pro lolos; baris (org,category,month) existing
--     lolos (itu edit via UPSERT, bukan bucket baru); else bucket bulan itu
--     ≥7 → QUOTA_EXCEEDED. Tanpa pengecualian ini, edit budget sah saat
--     sudah 7 bucket ikut diblok.
create or replace function public.enforce_budget_quota()
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
  if exists (select 1 from budgets
             where org_id = new.org_id
               and category = new.category
               and month = new.month) then
    return new;
  end if;
  select count(*) into v_used
  from budgets where org_id = new.org_id and month = new.month;
  if v_used >= 7 then
    raise exception 'QUOTA_EXCEEDED';
  end if;
  return new;
exception when others then
  if sqlerrm like '%QUOTA_EXCEEDED%' then
    raise;
  end if;
  return new;
end $$;

drop trigger if exists trg_budget_quota on budgets;
create trigger trg_budget_quota
  before insert on budgets
  for each row
  execute function public.enforce_budget_quota();

-- Fungsi trigger-only di atas sengaja TANPA grant ke siapa pun (tidak boleh
-- dipanggil sebagai RPC); penyimpangan sadar dari pola grant-to-authenticated
-- yang dipakai fungsi RPC di file ini.
revoke all on function public.enforce_workspace_quota() from public, anon, authenticated;
revoke all on function public.enforce_wallet_quota() from public, anon, authenticated;
revoke all on function public.enforce_budget_quota() from public, anon, authenticated;

-- Retention ai_usage 90 hari, guarded pola migration_13
-- (CI/lokal tanpa pg_cron = NOTICE + lewati; verifikasi penuh di Supabase).
DO $$ BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'SKIP pg_cron ext (bukan Supabase)';
END $$;

do $$
declare v_id bigint;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'SKIP retention cron (bukan Supabase)';
    return;
  end if;
  select jobid into v_id from cron.job where jobname = 'ssr_ai_usage_retention';
  if v_id is not null then perform cron.unschedule(v_id); end if;
  perform cron.schedule(
    'ssr_ai_usage_retention', '41 3 * * *',
    $q$delete from ai_usage where created_at < now() - interval '90 days'$q$
  );
end $$;
