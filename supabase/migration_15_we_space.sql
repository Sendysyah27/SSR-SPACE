-- SSR SPACE migration 15: We Space (mode bebas/bendahara + audit manual/kick).
-- Jalankan di Supabase Dashboard -> SQL Editor SETELAH migration_14.

alter table organizations
  add column if not exists space_mode text not null default 'bebas';
alter table organizations drop constraint if exists organizations_space_mode_check;
alter table organizations
  add constraint organizations_space_mode_check check (space_mode in ('bebas', 'bendahara'));

-- Helper tulis: satu-satunya pembaca org_members di jalur tulis (anti-recursion).
-- Policy RLS di bawah TIDAK subquery org_members langsung (aturan AGENTS.md).
create or replace function public.can_write_space(p_org_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from org_members m
    join organizations o on o.id = m.org_id
    where m.org_id = p_org_id
      and m.user_id = auth.uid()
      and (o.space_mode = 'bebas' or m.role in ('owner', 'admin'))
  );
$$;

revoke execute on function public.can_write_space(uuid) from public, anon;
grant execute on function public.can_write_space(uuid) to authenticated;

-- Pecah policy tulis wallets: SELECT tetap member-read, tulis via helper.
drop policy if exists "member wallets" on wallets;
drop policy if exists "member read wallets" on wallets;
create policy "member read wallets" on wallets
  for select using (exists (select 1 from org_members m where m.org_id = wallets.org_id and m.user_id = auth.uid()));
drop policy if exists "space write wallets" on wallets;
create policy "space write wallets" on wallets
  for insert with check (public.can_write_space(org_id));
drop policy if exists "space update wallets" on wallets;
create policy "space update wallets" on wallets
  for update using (public.can_write_space(org_id)) with check (public.can_write_space(org_id));
drop policy if exists "space delete wallets" on wallets;
create policy "space delete wallets" on wallets
  for delete using (public.can_write_space(org_id));

-- Pecah policy tulis transactions: pola sama.
drop policy if exists "member tx" on transactions;
drop policy if exists "member read tx" on transactions;
create policy "member read tx" on transactions
  for select using (exists (select 1 from org_members m where m.org_id = transactions.org_id and m.user_id = auth.uid()));
drop policy if exists "space write tx" on transactions;
create policy "space write tx" on transactions
  for insert with check (public.can_write_space(org_id));
drop policy if exists "space update tx" on transactions;
create policy "space update tx" on transactions
  for update using (public.can_write_space(org_id)) with check (public.can_write_space(org_id));
drop policy if exists "space delete tx" on transactions;
create policy "space delete tx" on transactions
  for delete using (public.can_write_space(org_id));

-- Ganti mode: hanya owner/admin, via RPC saja (tanpa policy UPDATE organizations).
create or replace function public.set_space_mode(p_org_id uuid, p_mode text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_myrole text;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_mode not in ('bebas', 'bendahara') then
    raise exception 'BAD_MODE';
  end if;
  select role into v_myrole from org_members
  where org_id = p_org_id and user_id = auth.uid();
  if v_myrole is null or v_myrole not in ('owner', 'admin') then
    raise exception 'NOT_ADMIN';
  end if;
  update organizations set space_mode = p_mode where id = p_org_id;
  insert into audit_logs (org_id, actor_user_id, event, meta)
  values (p_org_id, auth.uid(), 'space_mode_change', jsonb_build_object('mode', p_mode));
end $$;

revoke execute on function public.set_space_mode(uuid, text) from public, anon;
grant execute on function public.set_space_mode(uuid, text) to authenticated;

-- Audit insert manual (source_package null); auto tetap trigger lama.
create or replace function public.log_manual_tx_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.source_package is not null then
    return new;
  end if;
  insert into audit_logs (org_id, actor_user_id, event, meta)
  values (
    new.org_id,
    auth.uid(),
    'tx_manual_insert',
    jsonb_build_object(
      'tx_id', new.id,
      'amount', new.amount,
      'type', new.type,
      'category', new.category
    )
  );
  return new;
end $$;

drop trigger if exists trg_audit_manual_tx on transactions;
create trigger trg_audit_manual_tx
  after insert on transactions
  for each row
  execute function public.log_manual_tx_insert();

-- Audit kick: salin utuh function migration_14 + insert audit sebelum delete.
create or replace function public.kick_member(p_org_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_myrole text;
  v_target_role text;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  select role into v_myrole from org_members
  where org_id = p_org_id and user_id = v_uid;
  if v_myrole is null or v_myrole not in ('owner', 'admin') then
    raise exception 'NOT_ADMIN';
  end if;
  if p_user_id = v_uid then
    raise exception 'KICK_SELF';
  end if;
  select role into v_target_role from org_members
  where org_id = p_org_id and user_id = p_user_id;
  if v_target_role is null then
    raise exception 'NOT_MEMBER';
  end if;
  if v_target_role = 'owner'
     and (select count(*) from org_members
          where org_id = p_org_id and role = 'owner') <= 1 then
    raise exception 'KICK_LAST_OWNER';
  end if;
  insert into audit_logs (org_id, actor_user_id, event, meta)
  values (p_org_id, v_uid, 'member_kick', jsonb_build_object('target', p_user_id));
  delete from org_members where org_id = p_org_id and user_id = p_user_id;
end $$;

-- Catatan jujur: delete_workspace TANPA audit — FK cascade menghapus audit_logs
-- org tersebut, jadi baris auditnya ikut hilang. Jangan tambah insert mati di sini.

revoke execute on function public.kick_member(uuid, uuid) from public, anon;
grant execute on function public.kick_member(uuid, uuid) to authenticated;
