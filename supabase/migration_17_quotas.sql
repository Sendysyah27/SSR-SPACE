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
