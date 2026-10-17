-- Migration 23: tambah kolom currency ke wallets (idempotent)
-- User wajib jalankan manual sekali di Supabase SQL editor.

DO 21848
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'wallets' AND column_name = 'currency'
  ) THEN
    ALTER TABLE wallets ADD COLUMN currency TEXT NOT NULL DEFAULT 'IDR';
  END IF;
END 21848;

-- Pastikan nilai NULL (bila ada) jadi IDR
UPDATE wallets SET currency = 'IDR' WHERE currency IS NULL;
