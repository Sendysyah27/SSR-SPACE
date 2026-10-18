-- ========== migration_25_app_config.sql ==========
-- SSR SPACE migration 25: app_config (feature flags / konfigurasi aplikasi).
-- Jalankan di Supabase Dashboard -> SQL Editor (sekali; idempotent).
--
-- Isi: tabel key-value GLOBAL untuk feature flag & kill-switch fitur besar.
-- RLS aktif; client hanya boleh SELECT (tulis via Dashboard / service_role).
-- Aplikasi fail-closed: flag yang tak terbaca dianggap MATI
-- (lihat lib/services/app_config_service.dart).
--
-- Contoh pakai (di SQL Editor, setelah migration):
--   insert into app_config (key, value) values ('flag_nama_fitur', '1')
--   on conflict (key) do update set value = excluded.value,
--     updated_at = now();

create table if not exists app_config (
  key text primary key,
  value text not null default '',
  updated_at timestamptz not null default now()
);

alter table app_config enable row level security;

drop policy if exists app_config_read on app_config;
create policy app_config_read on app_config
  for select
  to authenticated
  using (true);
