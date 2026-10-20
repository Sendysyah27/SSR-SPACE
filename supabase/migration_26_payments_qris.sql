-- ========== migration_26_payments_qris.sql ==========
-- Status: BARU (mengikuti pola header & RLS migration_20_entitlement.sql)
-- Spec: BRIEF-QRIS-PAYMENT-SSRSPACE.md §5 / §10 (Batch 1 backend QRIS)
-- JALAN SETELAH (Sendy manual, Dashboard Supabase -> SQL Editor):
--   1. Buat tabel plan_pricing & payment_orders (create if not exists).
--   2. Seed 3 paket: 6bulan(30000/180), 1tahun(120000/365), permanen(133000/NULL).
--   3. Partial unique index unique_code aktif hanya di antara
--      status pending/awaiting_confirmation.
--   4. RLS aktif; client hanya SELECT miliknya, tulis via service role
--      (pola heartbeat migration_18: tanpa policy tulis client).
-- Idempotensi: create table/index if not exists, seed ON CONFLICT DO NOTHING.
-- Catatan: seed di bawah adalah HARGA DASAR (amount_base). amount_total =
--          amount_base + unique_code (100-999) dihitung oleh Edge Function
--          create-qris-order.

create table if not exists plan_pricing (
  plan_code text primary key,
  name text not null,
  price_idr integer not null check (price_idr >= 0),
  duration_days integer,
  benefits jsonb not null default '[]'::jsonb,
  is_active boolean not null default true
);

create table if not exists payment_orders (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  plan_code text not null references plan_pricing (plan_code),
  amount_base integer not null check (amount_base >= 0),
  unique_code integer not null check (unique_code between 100 and 999),
  amount_total integer not null check (amount_total = amount_base + unique_code),
  qris_payload text,
  status text not null default 'pending' check (
    status in (
      'pending',
      'awaiting_confirmation',
      'paid',
      'expired',
      'cancelled',
      'rejected'
    )
  ),
  expires_at timestamptz not null default now() + interval '24 hours',
  paid_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists payment_orders_unique_code_live
  on payment_orders (unique_code)
  where status in ('pending', 'awaiting_confirmation');

create index if not exists payment_orders_org_idx
  on payment_orders (org_id);
create index if not exists payment_orders_user_idx
  on payment_orders (user_id);
create index if not exists payment_orders_status_idx
  on payment_orders (status);

alter table plan_pricing enable row level security;
alter table payment_orders enable row level security;

drop policy if exists plan_pricing_select_all on plan_pricing;
create policy plan_pricing_select_all on plan_pricing for select using (true);

drop policy if exists payment_orders_select_own on payment_orders;
create policy payment_orders_select_own on payment_orders
  for select using (user_id = auth.uid());
-- Tidak ada policy INSERT/UPDATE/DELETE untuk client:
-- tulis hanya lewat service role (Edge Function) atau SQL Editor admin.

insert into plan_pricing (plan_code, name, price_idr, duration_days, benefits)
values
  (
    '6bulan',
    '6 Bulan',
    30000,
    180,
    '["Akses SSR-SPACE 6 bulan"]'::jsonb
  ),
  (
    '1tahun',
    '1 Tahun',
    120000,
    365,
    '["Akses SSR-SPACE 1 tahun"]'::jsonb
  ),
  (
    'permanen',
    'Permanen',
    133000,
    null,
    '["Akses SSR-SPACE permanen"]'::jsonb
  )
on conflict (plan_code) do nothing;
