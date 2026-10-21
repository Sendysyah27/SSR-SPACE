-- Migration 29: seed app_config 'ai_promo' (batch 284 tahap D).
-- Pola migration_28: idempotent (on conflict do nothing) + aman bila
-- app_config belum ada (exception undefined_table -> notice).
-- Nilai = label badge promo di entry "Record with AI" (kartu scan);
-- kosongkan / hapus baris ini via dashboard untuk menyembunyikan
-- badge. Apply MANUAL via Supabase dashboard (jalur Jhon/Sendy) —
-- file ini disiapkan koordinator, belum tentu sudah jalan di live.

do $$
begin
  insert into app_config (key, value)
  values ('ai_promo', 'FREE')
  on conflict (key) do nothing;
exception when undefined_table then
  raise notice 'app_config belum ada (migration_25 belum jalan) — seed ai_promo dilewati';
end $$;
