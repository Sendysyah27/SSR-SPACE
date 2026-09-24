-- SSR SPACE migration 07: perketat join workspace + mint_tx_code wajib member
-- Jalankan di Supabase Dashboard -> SQL Editor (sekali saja).

alter table organizations add column if not exists created_by uuid;

-- backfill: owner pertama dianggap pembuat
update organizations o
set created_by = (
  select m.user_id from org_members m
  where m.org_id = o.id and m.role = 'owner'
  limit 1
)
where o.created_by is null;

drop policy if exists "auth create org" on organizations;
create policy "auth create org" on organizations
  for insert to authenticated
  with check (created_by = auth.uid());

-- Self-join hanya untuk org yang user buat; owner/admin boleh tambah member lain.
drop policy if exists "join own org" on org_members;
create policy "join own org" on org_members
  for insert to authenticated
  with check (
    (
      user_id = auth.uid()
      and exists (
        select 1 from organizations o
        where o.id = org_id and o.created_by = auth.uid()
      )
    )
    or exists (
      select 1 from org_members m
      where m.org_id = org_id
        and m.user_id = auth.uid()
        and m.role in ('owner', 'admin')
    )
  );

-- Owner/admin boleh lihat anggota workspace-nya (untuk kelola member nanti)
drop policy if exists "member read org_members" on org_members;
create policy "member read org_members" on org_members
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from org_members m
      where m.org_id = org_id
        and m.user_id = auth.uid()
        and m.role in ('owner', 'admin')
    )
  );

create or replace function mint_tx_code(p_org_id uuid)
returns text language plpgsql security definer as $$
declare n int;
begin
  if not exists (
    select 1 from org_members m
    where m.org_id = p_org_id and m.user_id = auth.uid()
  ) then
    raise exception 'not a member of workspace';
  end if;

  insert into tx_sequences(org_id, last_number)
    values (p_org_id, 0) on conflict (org_id) do nothing;
  select last_number + 1 into n from tx_sequences
    where org_id = p_org_id for update;
  update tx_sequences set last_number = n where org_id = p_org_id;
  return 'TX-' || lpad(n::text, 6, '0');
end $$;

grant execute on function mint_tx_code(uuid) to authenticated;
