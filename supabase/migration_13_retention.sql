-- SSR SPACE migration 13: retention otomatis pg_cron (Fase 3 F3-d / backlog D6)
-- Jalankan di Supabase Dashboard → SQL Editor SETELAH migration_12.
--
-- Free plan Supabase: pg_cron tersedia (alternatif: aktifkan via
-- Dashboard → Database → Extensions bila create extension ditolak).
-- Job dijalankan sebagai role penjadwal (postgres) → lewati RLS, aman utk delete.
--
-- Retention:
--   client_errors      30 hari  (log error jangka pendek)
--   audit_logs        180 hari  (jejak keamanan cukup 6 bulan, hemat DB)
--   cron.job_run_details 14 hari (mencegah tabel pg_cron membengkak —
--                                 peringatan resmi Supabase soal gagal upgrade)

create extension if not exists pg_cron;

-- Idempotent: bila job sudah ada, unschedule dulu lalu jadwalkan ulang.
do $$
declare v_id bigint;
begin
  select jobid into v_id from cron.job where jobname = 'ssr_client_errors_retention';
  if v_id is not null then perform cron.unschedule(v_id); end if;
  perform cron.schedule(
    'ssr_client_errors_retention', '17 3 * * *',
    $q$delete from client_errors where created_at < now() - interval '30 days'$q$
  );
end $$;

do $$
declare v_id bigint;
begin
  select jobid into v_id from cron.job where jobname = 'ssr_audit_logs_retention';
  if v_id is not null then perform cron.unschedule(v_id); end if;
  perform cron.schedule(
    'ssr_audit_logs_retention', '23 3 * * *',
    $q$delete from audit_logs where created_at < now() - interval '180 days'$q$
  );
end $$;

do $$
declare v_id bigint;
begin
  select jobid into v_id from cron.job where jobname = 'ssr_cron_run_details_retention';
  if v_id is not null then perform cron.unschedule(v_id); end if;
  perform cron.schedule(
    'ssr_cron_run_details_retention', '29 3 * * *',
    $q$delete from cron.job_run_details where start_time < now() - interval '14 days'$q$
  );
end $$;
