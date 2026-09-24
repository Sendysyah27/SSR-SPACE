-- SSR SPACE migration 05: kode transaksi TX-000001 per workspace
alter table transactions add column if not exists code text;

create table if not exists tx_sequences (
  org_id uuid primary key references organizations(id) on delete cascade,
  last_number int not null default 0
);

alter table tx_sequences enable row level security;

create or replace function mint_tx_code(p_org_id uuid)
returns text language plpgsql security definer as $$
declare n int;
begin
  insert into tx_sequences(org_id, last_number)
    values (p_org_id, 0) on conflict (org_id) do nothing;
  select last_number + 1 into n from tx_sequences
    where org_id = p_org_id for update;
  update tx_sequences set last_number = n where org_id = p_org_id;
  return 'TX-' || lpad(n::text, 6, '0');
end $$;

grant execute on function mint_tx_code(uuid) to authenticated;

with ranked as (
  select id, row_number() over (partition by org_id order by date, created_at) as rn
  from transactions where code is null
)
update transactions t set code = 'TX-' || lpad(ranked.rn::text, 6, '0')
from ranked where t.id = ranked.id;

with mx as (select org_id, count(*) as c from transactions group by org_id)
insert into tx_sequences(org_id, last_number)
select org_id, c from mx
on conflict (org_id) do update set last_number = excluded.last_number;
