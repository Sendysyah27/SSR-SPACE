-- ========== migration_28_ai_learning.sql ==========
-- SSR SPACE migration 28: lingkar belajar Mang AI (batch 281D).
-- Jalankan di Supabase Dashboard -> SQL Editor (sekali; idempotent).
--
-- Isi:
-- 1) ai_correction_events: event koreksi kartu konfirmasi AI — payload
--    JSON verbatim (nilai asal AI vs nilai final user + konteks).
--    Append-only dari klien: SELECT + INSERT milik sendiri saja.
-- 2) user_merchant_aliases: memori alias merchant per user/org —
--    teks merchant/catatan ternormalisasi -> kategori + dompet pilihan
--    user, dengan hitungan pemakaian (upsert dari klien).
-- 3) Seed app_config 'quick_record_rules': kosakata kategori + petunjuk
--    parse yang dibaca app sebagai konfigurasi server (batch 281D
--    tahap 3). Ubah nilainya via SQL Editor untuk mengubah perilaku
--    parse TANPA rilis app. Seed hanya bila tabel app_config ada
--    (migration_25) dan kunci belum terisi.

create table if not exists ai_correction_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_ai_correction_events_user_created
  on ai_correction_events (user_id, created_at desc);

alter table ai_correction_events enable row level security;

drop policy if exists ai_correction_events_select_own on ai_correction_events;
create policy ai_correction_events_select_own on ai_correction_events
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists ai_correction_events_insert_own on ai_correction_events;
create policy ai_correction_events_insert_own on ai_correction_events
  for insert
  to authenticated
  with check (user_id = auth.uid());

create table if not exists user_merchant_aliases (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  merchant_key text not null,
  category text,
  wallet_name text,
  use_count int not null default 1,
  last_used_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (org_id, user_id, merchant_key)
);

alter table user_merchant_aliases enable row level security;

drop policy if exists user_merchant_aliases_select_own on user_merchant_aliases;
create policy user_merchant_aliases_select_own on user_merchant_aliases
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists user_merchant_aliases_insert_own on user_merchant_aliases;
create policy user_merchant_aliases_insert_own on user_merchant_aliases
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists user_merchant_aliases_update_own on user_merchant_aliases;
create policy user_merchant_aliases_update_own on user_merchant_aliases
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

do $$
begin
  insert into app_config (key, value)
  values (
    'quick_record_rules',
    '{"version":1,"category_hints":{"kopi":"Minuman","kopken":"Minuman","starbucks":"Minuman","indomaret":"Belanja","alfamart":"Belanja","grab":"Transportasi","gojek":"Transportasi","spbu":"Transportasi","pertamina":"Transportasi","pln":"Tagihan","pdam":"Tagihan","apotek":"Kesehatan"},"parse_hints":["Nominal ditulis angka penuh rupiah tanpa titik ribuan.","Catatan/merchant diambil dari teks user apa adanya."]}'
  )
  on conflict (key) do nothing;
exception when undefined_table then
  raise notice 'app_config belum ada (migration_25 belum jalan) — seed quick_record_rules dilewati';
end $$;
