-- SSR SPACE migration 19: realtime sync (Batch 6 Sprint).
-- Event UPDATE/DELETE butuh REPLICA IDENTITY FULL agar payload
-- baris lama lengkap (batasan Postgres, bukan Supabase).
-- Publication guarded: CI/lokal tanpa publication supabase_realtime
-- = lewati diam-diam (di Supabase asli selalu ada).

alter table transactions replica identity full;
alter table org_members replica identity full;
alter table wallets replica identity full;
alter table budgets replica identity full;

do $$
declare
  t text;
begin
  if not exists (select 1 from pg_publication
                 where pubname = 'supabase_realtime') then
    raise notice 'SKIP realtime publication (bukan Supabase)';
    return;
  end if;
  foreach t in array array[
    'transactions', 'org_members', 'wallets', 'budgets'
  ] loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime'
                     and tablename = t::name) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end $$;
