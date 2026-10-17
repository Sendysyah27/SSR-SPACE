-- ========== migration_22_announcements.sql ==========
-- SSR SPACE migration 22: announcements + roadmap (Fase 4 Ollo-adapt).
-- Spec: docs/superpowers/specs/2026-10-17-ollo-fase4-announcements-roadmap-design.md §4.
-- Jalankan di Supabase Dashboard → SQL Editor SETELAH migration_21
-- (fresh install: schema.sql + migration_squashed.sql +
--  migration_20_entitlement.sql + migration_21_gamification.sql + file ini).
--
-- Isi: 3 tabel RPC-only (announcements, roadmap_items, announcement_reads) +
-- RPC list_announcements (aktif + status baca per-user) / ack_announcements
-- (tandai dibaca) / list_roadmap + seed awal. Tabel RLS aktif TANPA policy
-- client (pola user_achievements migration_21) — baca/tulis langsung dari
-- client ditolak; hanya lewat RPC.
-- Idempotent: boleh dijalankan ulang (IF NOT EXISTS / OR REPLACE / seed
-- ON CONFLICT DO NOTHING).

-- 1. announcements: slug id buatan owner (id notifikasi stabil, enak ditulis
--    di SQL Editor). kind dipakai UI: info|promo|update.
create table if not exists announcements (
  id text primary key,
  title text not null,
  body text not null,
  kind text not null default 'info'
    check (kind in ('info', 'promo', 'update')),
  pinned boolean not null default false,
  published_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

alter table announcements enable row level security;

create index if not exists announcements_published_idx
  on announcements (published_at desc);

-- 2. roadmap_items: status UI: planned|in_progress|done.
create table if not exists roadmap_items (
  id text primary key,
  title text not null,
  description text,
  status text not null default 'planned'
    check (status in ('planned', 'in_progress', 'done')),
  sort_order int not null default 0,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table roadmap_items enable row level security;

create index if not exists roadmap_items_sort_idx
  on roadmap_items (sort_order);

-- 3. announcement_reads: status baca per-user (per auth.uid()).
create table if not exists announcement_reads (
  user_id uuid not null references auth.users(id) on delete cascade,
  announcement_id text not null references announcements(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (user_id, announcement_id)
);

alter table announcement_reads enable row level security;

create index if not exists announcement_reads_user_idx
  on announcement_reads (user_id);

-- 4. list_announcements: pengumuman aktif + flag read per-user.
--    Aktif = published_at <= now() dan (expires_at null atau > now()).
--    NOT_AUTHENTICATED bila belum login.
create or replace function public.list_announcements()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', a.id,
               'title', a.title,
               'body', a.body,
               'kind', a.kind,
               'pinned', a.pinned,
               'published_at', a.published_at,
               'read', exists (
                 select 1 from announcement_reads r
                 where r.user_id = v_uid and r.announcement_id = a.id
               )
             )
             order by a.pinned desc, a.published_at desc
           ), '[]'::jsonb)
  into v_result
  from announcements a
  where a.published_at <= now()
    and (a.expires_at is null or a.expires_at > now());

  return v_result;
end $$;

revoke all on function public.list_announcements() from public, anon;
grant execute on function public.list_announcements() to authenticated;

-- 5. ack_announcements: tandai pengumuman dibaca (idempoten).
create or replace function public.ack_announcements(p_ids text[])
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  -- Lewati id yang tidak ada (dihapus/di-expired) agar satu id basi tidak
  -- membatalkan seluruh batch (FK violation). Batch boleh berisi >1 id.
  insert into announcement_reads (user_id, announcement_id)
  select auth.uid(), p
  from unnest(p_ids) as p
  where exists (select 1 from announcements a where a.id = p)
  on conflict (user_id, announcement_id) do nothing;
end $$;

revoke all on function public.ack_announcements(text[]) from public, anon;
grant execute on function public.ack_announcements(text[]) to authenticated;

-- 6. list_roadmap: semua item urut sort_order asc, updated_at desc.
create or replace function public.list_roadmap()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', r.id,
               'title', r.title,
               'description', r.description,
               'status', r.status,
               'sort_order', r.sort_order,
               'updated_at', r.updated_at
             )
             order by r.sort_order asc, r.updated_at desc
           ), '[]'::jsonb)
  into v_result
  from roadmap_items r;

  return v_result;
end $$;

revoke all on function public.list_roadmap() from public, anon;
grant execute on function public.list_roadmap() to authenticated;

-- 7. Seed idempotent (owner bebas edit/hapus lewat SQL Editor).
insert into announcements (id, title, body, kind, pinned)
values (
  '2026-10-17-selamat-datang',
  'Selamat datang di Pengumuman & Roadmap',
  'Mulai sekarang kabar terbaru aplikasi muncul di sini. Buka Pengumuman untuk '
    || 'membaca info, promo, dan catatan pembaruan; cek Roadmap untuk melihat '
    || 'rencana dan progres fitur berikutnya.',
  'info',
  true
)
on conflict (id) do nothing;

insert into roadmap_items (id, title, description, status, sort_order)
values
  ('rm-announcements', 'Pengumuman dalam aplikasi',
   'Kabar dan promo terbaru langsung di aplikasi.', 'done', 10),
  ('rm-roadmap', 'Roadmap publik',
   'Rencana dan progres fitur yang sedang dikerjakan.', 'done', 20),
  ('rm-update-log', 'Riwayat pembaruan',
   'Catatan perubahan tiap versi di satu tempat.', 'in_progress', 30),
  ('rm-i18n', 'Dukungan bahasa penuh',
   'Rapikan terjemahan Indonesia dan Inggris di seluruh layar.', 'planned', 40),
  ('rm-multicurrency', 'Multi-mata uang',
   'Catat transaksi dengan mata uang selain Rupiah.', 'planned', 50)
on conflict (id) do nothing;
