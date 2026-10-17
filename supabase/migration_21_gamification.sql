-- ========== migration_21_gamification.sql ==========
-- SSR SPACE migration 21: gamifikasi server (Fase 3 Ollo-adapt).
-- Spec: docs/superpowers/specs/2026-10-17-ollo-fase3-gamification-design.md §4.
-- Jalankan di Supabase Dashboard → SQL Editor SETELAH migration_20
-- (fresh install: schema.sql + migration_squashed.sql +
--  migration_20_entitlement.sql + file ini).
--
-- Isi: indeks streak (created_by,date) + tabel RPC-only user_achievements +
-- RPC gamification_status (streak/XP/level + 8 badge server-derivable, kunci
-- saat dipanggil) + ack_achievements (dedupe notif lintas-device via
-- notified_at). Streak/tx100/save1m global (created_by = auth.uid(), lintas
-- workspace); clean30 org-scoped (budget memang per-org).
-- Idempotent: boleh dijalankan ulang (IF NOT EXISTS / CREATE OR REPLACE).

-- 1. Indeks pendukung streak global (scan distinct date per user).
create index if not exists transactions_created_by_date_idx
  on transactions (created_by, date);

-- 2. Tabel RPC-only: RLS aktif TANPA policy client (pola user_entitlements/
--    ai_usage) — baca/tulis langsung dari client = ditolak; hanya lewat RPC.
create table if not exists user_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id text not null,
  unlocked_at timestamptz not null default now(),
  notified_at timestamptz,
  primary key (user_id, badge_id)
);

alter table user_achievements enable row level security;

create index if not exists user_achievements_user_notified_idx
  on user_achievements (user_id, notified_at);

-- 3. gamification_status: status gamifikasi user untuk konteks workspace.
--    Streak/XP/badge dihitung read-time (spec §8: aman untuk skala sekarang;
--    materialisasi = follow-up). NOT_AUTHENTICATED / NOT_MEMBER bila gagal.
create or replace function public.gamification_status(p_org_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_month text := to_char(current_date, 'YYYY-MM');
  v_dates date[];
  v_n int;
  v_i int;
  v_last date;
  v_prev date;
  v_run int := 0;
  v_best int := 0;
  v_streak int := 0;
  v_today_done boolean := false;
  v_grace boolean := false;
  v_tx_count int := 0;
  v_saved numeric := 0;
  v_clean30 boolean := false;
  v_badges jsonb;
  v_new_badges jsonb;
  v_ach_count int := 0;
  v_xp int := 0;
  v_level int := 1;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if not exists (select 1 from org_members
                 where org_id = p_org_id and user_id = v_uid) then
    raise exception 'NOT_MEMBER';
  end if;

  -- 3a. Streak global: distinct tanggal catat user (<= hari ini), menaik.
  select array(
    select distinct t.date
    from transactions t
    where t.created_by = v_uid
      and t.date <= current_date
    order by t.date
  ) into v_dates;

  v_n := coalesce(array_length(v_dates, 1), 0);

  -- streak_days: run beruntun berakhir hari ini; grace = hari ini kosong tapi
  -- kemarin ada → anchor kemarin (konsisten dailyStreak klien).
  if v_n > 0 then
    v_last := v_dates[v_n];
    v_today_done := (v_last = current_date);
    if v_last = current_date or v_last = current_date - 1 then
      v_streak := 1;
      v_i := v_n;
      while v_i > 1 and v_dates[v_i - 1] = v_dates[v_i] - 1 loop
        v_streak := v_streak + 1;
        v_i := v_i - 1;
      end loop;
    end if;
    -- streak_best: run beruntun terpanjang dari seluruh tanggal.
    for v_i in 1..v_n loop
      if v_prev is null or v_dates[v_i] <> v_prev + 1 then
        v_run := 1;
      else
        v_run := v_run + 1;
      end if;
      if v_run > v_best then
        v_best := v_run;
      end if;
      v_prev := v_dates[v_i];
    end loop;
  end if;

  -- grace_used = hari ini kosong DAN streak benar-benar dipinjam dari kemarin
  -- (streak = 0 saat tanpa anchor → grace tak dipakai, paritas klien).
  v_grace := (not v_today_done) and v_streak > 0;

  -- 3b. Metric global user.
  select count(*) into v_tx_count
  from transactions where created_by = v_uid;

  select coalesce(sum(t.amount), 0) into v_saved
  from transactions t
  where t.created_by = v_uid
    and t.type = 'out'
    and (lower(t.category) like '%tabung%' or lower(t.category) like '%saving%');

  -- 3c. clean30 org-scoped bulan berjalan: ada budget DAN setiap budget
  --     non-tabungan spend <= limit. Belanja dikelompokkan per kategori
  --     lapis-atas (paritas topOf klien), dibanding top_of(budget.category),
  --     kategori kosong → 'Lainnya'. Budget kategori tabungan diabaikan.
  select
    exists (select 1 from budgets b
            where b.org_id = p_org_id and b.month = v_month)
    and not exists (
      select 1
      from budgets b
      left join (
        select coalesce(nullif(split_part(t.category, ' > ', 1), ''), 'Lainnya') as top,
               sum(t.amount) as spent
        from transactions t
        where t.org_id = p_org_id
          and t.type = 'out'
          and not (lower(t.category) like '%tabung%' or lower(t.category) like '%saving%')
          and t.date >= date_trunc('month', current_date)::date
          and t.date < (date_trunc('month', current_date) + interval '1 month')::date
        group by 1
      ) sp
        on sp.top = coalesce(nullif(split_part(b.category, ' > ', 1), ''), 'Lainnya')
      where b.org_id = p_org_id
        and b.month = v_month
        and not (lower(b.category) like '%tabung%' or lower(b.category) like '%saving%')
        and coalesce(sp.spent, 0) > b.limit_amount
    )
  into v_clean30;

  -- 3d. Unlock badge server-derivable yang terpenuhi (idempoten).
  insert into user_achievements (user_id, badge_id)
  select v_uid, b
  from unnest(array[
    case when v_streak >= 3   then 'streak3'   end,
    case when v_streak >= 7   then 'streak7'   end,
    case when v_streak >= 14  then 'streak14'  end,
    case when v_streak >= 30  then 'streak30'  end,
    case when v_streak >= 100 then 'streak100' end,
    case when v_tx_count >= 100 then 'tx100'   end,
    case when v_saved >= 1000000 then 'save1m' end,
    case when v_clean30 then 'clean30' end
  ]) as t(b)
  where b is not null
  on conflict (user_id, badge_id) do nothing;

  -- 3e. Badge + new_badges (belum dinotifikasi) + XP/level server.
  select coalesce(
           jsonb_agg(
             jsonb_build_object('id', badge_id, 'unlocked_at', unlocked_at)
             order by badge_id
           ), '[]'::jsonb)
  into v_badges
  from user_achievements where user_id = v_uid;

  select coalesce(jsonb_agg(badge_id order by badge_id), '[]'::jsonb)
  into v_new_badges
  from user_achievements
  where user_id = v_uid and notified_at is null;

  select count(*) into v_ach_count
  from user_achievements where user_id = v_uid;

  v_xp := least(v_tx_count, 200) * 10 + v_streak * 5 + v_ach_count * 50;

  select count(*) into v_level
  from unnest(array[0, 200, 500, 1000, 2000, 3500, 5500]) as f
  where v_xp >= f;

  return jsonb_build_object(
    'streak_days', v_streak,
    'streak_best', v_best,
    'streak_today_done', v_today_done,
    'streak_grace_used', v_grace,
    'xp', v_xp,
    'level', v_level,
    'badges', v_badges,
    'new_badges', v_new_badges
  );
end $$;

revoke all on function public.gamification_status(uuid) from public, anon;
grant execute on function public.gamification_status(uuid) to authenticated;

-- 4. ack_achievements: tandai badge sudah dinotifikasi (dedupe lintas-device).
create or replace function public.ack_achievements(p_ids text[])
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  update user_achievements
  set notified_at = now()
  where user_id = auth.uid()
    and badge_id = any(p_ids)
    and notified_at is null;
end $$;

revoke all on function public.ack_achievements(text[]) from public, anon;
grant execute on function public.ack_achievements(text[]) to authenticated;
