-- Migration 24: update status roadmap Fase 5 jadi done (idempotent)
-- User wajib jalankan manual sekali di Supabase SQL editor.

UPDATE roadmap SET status = 'done' WHERE id IN (
  'rm-announcements',
  'rm-roadmap',
  'rm-update-log',
  'rm-i18n',
  'rm-multicurrency'
);
