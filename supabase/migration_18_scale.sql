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
