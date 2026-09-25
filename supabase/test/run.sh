#!/usr/bin/env bash
# Terapkan setup + schema + semua migration, lalu jalankan suite RLS.
# Dipakai lokal dan CI. Var: SSR_RLS_DB_URL (default: docker service CI).
# Catatan: migration_13 (retention pg_cron) dilewati — butuh ekstensi pg_cron
# yang tidak ada di Postgres CI/lokal; diverifikasi manual di Supabase.
set -euo pipefail
cd "$(dirname "$0")"

DB="${SSR_RLS_DB_URL:-postgresql://postgres:postgres@127.0.0.1:5432/ssr_test}"

echo "== reset skema"
psql "$DB" -v ON_ERROR_STOP=1 -q <<'SQL'
drop schema if exists public cascade;
create schema public;
drop schema if exists auth cascade;
SQL

# Urutan glob aman: migration_02..09 diawali '0', lalu 10, 11, 12.
for f in setup.sql ../schema.sql ../migration_*.sql rls_test.sql; do
  case "$f" in
    *migration_13*)
      echo "== skip $f (butuh pg_cron; retention di Supabase)"
      continue
      ;;
  esac
  echo "== apply $f"
  psql "$DB" -v ON_ERROR_STOP=1 -q -f "$f"
done

echo "== SUKSES: suite RLS lulus"
