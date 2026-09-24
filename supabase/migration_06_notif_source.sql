-- SSR SPACE migration 06: sumber pelacakan notifikasi otomatis
alter table transactions add column if not exists source_package text;
alter table transactions add column if not exists source_hash text;

create unique index if not exists unique_tx_hash
  on transactions(org_id, source_hash) where source_hash is not null;
