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
