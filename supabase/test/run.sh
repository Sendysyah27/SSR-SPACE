#!/usr/bin/env bash
# Terapkan setup + schema + baseline squash, lalu jalankan suite RLS.
# Dipakai lokal dan CI. Var: SSR_RLS_DB_URL (default: docker service CI).
# Blok pg_cron di baseline guarded (NOTICE + lewati bila ext tak ada),
# jadi tak perlu skip file lagi; verifikasi penuh di Supabase.
set -euo pipefail
cd "$(dirname "$0")"

DB="${SSR_RLS_DB_URL:-postgresql://postgres:postgres@127.0.0.1:5432/ssr_test}"

echo "== reset skema"
psql "$DB" -v ON_ERROR_STOP=1 -q <<'SQL'
drop schema if exists public cascade;
create schema public;
drop schema if exists auth cascade;
SQL

# Baseline tunggal (pengganti migration_02..19, squash Batch 7).
for f in setup.sql ../schema.sql ../migration_squashed.sql rls_test.sql; do
  echo "== apply $f"
  psql "$DB" -v ON_ERROR_STOP=1 -q -f "$f"
done

echo "== SUKSES: suite RLS lulus"
