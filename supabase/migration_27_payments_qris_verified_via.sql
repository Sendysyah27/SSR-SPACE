-- ========== migration_27_payments_qris_verified_via.sql ==========
-- Tambahan kecil mengikuti BRIEF-QRIS-PAYMENT-SSRSPACE.md §5.2:
-- kolom verified_via belum ada di migration_26 yang ter-commit.
-- Aditif & idempoten — aman dijalankan setelah migration_26
-- (Supabase Dashboard -> SQL Editor, manual oleh Sendy).
-- Nilai: 'notif_auto' (watcher notifikasi HP) / 'manual' (approve Sendy).

alter table payment_orders
  add column if not exists verified_via text;
