-- Stub lingkungan Supabase untuk test RLS di Postgres polos.
-- Dijalankan paling awal oleh run.sh SEBELUM schema.sql.
-- Tujuan: mereproduksi role + default privileges + auth.uid() milik Supabase
-- supaya perilaku RLS sama dengan production (bukan test tanpa auth).

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  created_at timestamptz default now()
);

-- auth.uid() membaca GUC sesi test.user_id (di-set per aktor di rls_test.sql).
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('test.user_id', true), '')::uuid
$$;

-- Replikasi default privileges proyek Supabase (grant all on tables ke client roles).
-- Harus SEBELUM schema.sql membuat tabel.
grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant usage, select on sequences to anon, authenticated, service_role;
