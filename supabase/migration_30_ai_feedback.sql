-- ========== migration_30_ai_feedback.sql ==========
-- SSR SPACE migration 30: umpan balik jawaban Mode Asisten (batch 285
-- tahap B). Jalankan di Supabase Dashboard -> SQL Editor (sekali;
-- idempotent). Apply = jalur dashboard Jhon/Sendy (BUKAN dari app).
--
-- Isi:
-- ai_assistant_feedback: satu baris per rating 👍/👎 user atas balasan
-- Asisten Mang AI. context = cuplikan balasan yang SUDAH dimasking PII
-- di klien (ai_assistant_feedback.dart, maks 200 char) — bukan teks
-- mentah user. Klien menulis best-effort (fail-open): selama migration
-- ini belum jalan, insert gagal senyap dan antrean lokal menunggu.

create table if not exists ai_assistant_feedback (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  rating int not null check (rating in (-1, 1)),
  context text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists idx_ai_assistant_feedback_user_created
  on ai_assistant_feedback (user_id, created_at desc);

alter table ai_assistant_feedback enable row level security;

drop policy if exists ai_assistant_feedback_select_own on ai_assistant_feedback;
create policy ai_assistant_feedback_select_own on ai_assistant_feedback
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists ai_assistant_feedback_insert_own on ai_assistant_feedback;
create policy ai_assistant_feedback_insert_own on ai_assistant_feedback
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists ai_assistant_feedback_update_own on ai_assistant_feedback;
create policy ai_assistant_feedback_update_own on ai_assistant_feedback
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
