-- Suite test RLS SSR SPACE — dijalankan run.sh SETELAH schema + baseline squash.
-- Aktor: `set role authenticated` + `set test.user_id = '<uuid>'` (lihat setup.sql).
-- Konvensi: kegagalan assert = exception → psql ON_ERROR_STOP → CI merah.

-- ===== Helper =====
create or replace function public.t_assert(p_ok boolean, p_name text)
returns text language plpgsql as $$
begin
  if p_ok is distinct from true then
    raise exception 'ASSERT GAGAL: %', p_name;
  end if;
  return 'ok: ' || p_name;
end $$;

-- ===== Fixture =====
insert into auth.users (id) values
  ('11111111-1111-4111-8111-111111111111'),  -- alice
  ('22222222-2222-4222-8222-222222222222'),  -- bob (pengintai)
  ('33333333-3333-4333-8333-333333333333')   -- carol (join via invite)
on conflict (id) do nothing;

-- Org dibuat lewat jalur kebijakan (uji positif "auth create org" + "join own org")
set role authenticated;

set test.user_id = '11111111-1111-4111-8111-111111111111';
insert into organizations (id, name, created_by)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Org A',
        '11111111-1111-4111-8111-111111111111');
insert into org_members (org_id, user_id, role)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
        '11111111-1111-4111-8111-111111111111', 'owner');

set test.user_id = '22222222-2222-4222-8222-222222222222';
insert into organizations (id, name, created_by)
values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Org B',
        '22222222-2222-4222-8222-222222222222');
insert into org_members (org_id, user_id, role)
values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
        '22222222-2222-4222-8222-222222222222', 'owner');

-- Seed data org A (superuser, bypass RLS) supaya tes isolasi baca bermakna.
reset role;
insert into wallets (id, org_id, name, type) values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Kas A', 'cash'),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeee02', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Kas B', 'cash');
insert into transactions (id, org_id, type, amount, wallet_id, category, note, date, created_by) values
  ('dddddddd-dddd-4ddd-8ddd-ddddddddddd1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
   'in', 50000, 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01', 'Gaji', 'seed', current_date,
   '11111111-1111-4111-8111-111111111111'),
  ('dddddddd-dddd-4ddd-8ddd-ddddddddddd2', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
   'out', 10000, 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee02', 'Makan', 'seed', current_date,
   '22222222-2222-4222-8222-222222222222');
insert into budgets (org_id, category, month, limit_amount)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Makan', '2026-09', 500000);
insert into subscriptions (org_id, plan, status)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'pro', 'active');

-- ===== T01: regresi migration_08 (RLS recursion) =====
-- Dulu: policy SELECT org_members subquery org_members → "Gagal memuat dompet".
set role authenticated;
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert((select count(*) from org_members) = 1,
  'T01 baca org_members sendiri tanpa recursion');
select t_assert((select count(*) from wallets) = 1,
  'T01 baca wallets member (query org_members) tanpa recursion');
select t_assert((select count(*) from organizations) = 1,
  'T01 baca organizations member');

-- ===== T02: isolasi baca lintas org (bob vs org A) =====
set test.user_id = '22222222-2222-4222-8222-222222222222';
select t_assert((select count(*) from organizations) = 1,
  'T02 bob hanya melihat Org B');
select t_assert((select count(*) from wallets where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 0,
  'T02 wallets org A tak terlihat bob');
select t_assert((select count(*) from transactions where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 0,
  'T02 transaksi org A tak terlihat bob');
select t_assert((select count(*) from audit_logs where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 0,
  'T02 audit_logs org A tak terlihat bob');
select t_assert((select count(*) from budgets where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 0,
  'T02 budgets org A tak terlihat bob');
select t_assert((select count(*) from subscriptions where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 0,
  'T02 subscriptions org A tak terlihat bob');
select t_assert((select count(*) from org_members where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 0,
  'T02 keanggotaan org A tak terlihat bob');

-- ===== T03: tulis lintas org ditolak =====
do $$
begin
  insert into wallets (org_id, name) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'jebol');
  raise exception 'ASSERT GAGAL: T03 insert wallet lintas org lolos';
exception when sqlstate '42501' then null;
end $$;

do $$
begin
  insert into transactions (org_id, type, amount)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 1000);
  raise exception 'ASSERT GAGAL: T03 insert transaksi lintas org lolos';
exception when sqlstate '42501' then null;
end $$;

do $$
declare n int;
begin
  update transactions set note = 'jebol'
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  get diagnostics n = row_count;
  if n <> 0 then
    raise exception 'ASSERT GAGAL: T03 update lintas org kena % baris', n;
  end if;
exception when sqlstate '42501' then null;
end $$;
-- verifikasi sebagai alice (bob tak bisa melihat org A sama sekali)
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert(
  (select note from transactions where id = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1') = 'seed',
  'T03 transaksi org A tak berubah');
set test.user_id = '22222222-2222-4222-8222-222222222222';

do $$
begin
  insert into budgets (org_id, category, month, limit_amount)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Jebol', '2026-09', 1);
  raise exception 'ASSERT GAGAL: T03 insert budget lintas org lolos';
exception when sqlstate '42501' then null;
end $$;

-- ===== T04: auto-join org korban ditolak =====
do $$
begin
  insert into org_members (org_id, user_id)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '22222222-2222-4222-8222-222222222222');
  raise exception 'ASSERT GAGAL: T04 auto-join org korban lolos';
exception when sqlstate '42501' then null;
end $$;
select t_assert(
  not exists (
    select 1 from org_members
    where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
      and user_id = '22222222-2222-4222-8222-222222222222'
  ),
  'T04 bob tetap bukan member org A');

-- ===== T05: mint_tx_code wajib member =====
set test.user_id = '22222222-2222-4222-8222-222222222222';
do $$
begin
  perform public.mint_tx_code('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1');
  raise exception 'ASSERT GAGAL: T05 mint_tx_code non-member lolos';
exception when others then
  if sqlerrm not like '%not a member of workspace%' then
    raise;
  end if;
end $$;
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert(public.mint_tx_code('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 'TX-000001',
  'T05 mint_tx_code member menghasilkan TX-000001');

-- ===== T06: rate limit auto-insert 10/60s/org + audit trigger =====
do $$
declare i int;
begin
  for i in 1..10 loop
    insert into transactions (org_id, type, amount, source_package)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 1000, 'id.dana');
  end loop;
  begin
    insert into transactions (org_id, type, amount, source_package)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 1000, 'id.dana');
    raise exception 'ASSERT GAGAL: T06 rate limit 10/60s tidak aktif';
  exception when others then
    if sqlerrm not like '%RATE_LIMITED%' then
      raise;
    end if;
  end;
  insert into transactions (org_id, type, amount, source_package)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 7777, null);
end $$;
select t_assert(
  (select count(*) from transactions
   where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1' and source_package = 'id.dana') = 10,
  'T06 tepat 10 auto-insert tersimpan');
select t_assert(
  (select count(*) from transactions
   where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
     and amount = 7777 and source_package is null) = 1,
  'T06 insert manual bebas rate limit');
select t_assert(
  (select count(*) from audit_logs
   where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1' and event = 'tx_auto_insert') = 10,
  'T06 audit tx_auto_insert tercatat 10');

-- ===== T07: audit_logs client write ditolak =====
set test.user_id = '22222222-2222-4222-8222-222222222222';
do $$
begin
  insert into audit_logs (org_id, event)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'forged');
  raise exception 'ASSERT GAGAL: T07 client insert audit_logs lolos';
exception when sqlstate '42501' then null;
end $$;
-- verifikasi sebagai alice: baris forgery harus tak tersimpan di DB manapun
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert(
  (select count(*) from audit_logs
   where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1' and event = 'forged') = 0,
  'T07 audit_logs forgery tak tersimpan');
set test.user_id = '22222222-2222-4222-8222-222222222222';

-- ===== T08: client_errors hanya milik sendiri =====
do $$
begin
  insert into client_errors (user_id, message, app_version)
  values ('11111111-1111-4111-8111-111111111111', 'error punya alice', 'test');
  raise exception 'ASSERT GAGAL: T08 tulis error milik user lain lolos';
exception when sqlstate '42501' then null;
end $$;
insert into client_errors (user_id, message, app_version)
values ('22222222-2222-4222-8222-222222222222', 'error bob', 'test');
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert(
  (select count(*) from client_errors
   where user_id = '22222222-2222-4222-8222-222222222222') = 0,
  'T08 client_errors lintas user tak terlihat');

-- ===== T09: invite workspace (hash, sekali pakai, admin only) =====
set test.user_id = '22222222-2222-4222-8222-222222222222';
do $$
begin
  insert into org_invites (org_id, created_by, token_hash)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
          '22222222-2222-4222-8222-222222222222', 'deadbeef');
  raise exception 'ASSERT GAGAL: T09 non-admin buat invite lolos';
exception when sqlstate '42501' then null;
end $$;

set test.user_id = '11111111-1111-4111-8111-111111111111';
insert into org_invites (org_id, role, token_hash, created_by, max_uses)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'member',
        encode(sha256(convert_to('ABCD1234', 'UTF8')), 'hex'),
        '11111111-1111-4111-8111-111111111111', 1);
select t_assert(
  not exists (select 1 from org_invites where token_hash in ('ABCD1234', 'abcd1234')),
  'T09 token asli tak pernah disimpan (hanya hash)');

set test.user_id = '22222222-2222-4222-8222-222222222222';
select t_assert(
  (select count(*) from org_invites where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 0,
  'T09 invite tak terbaca non-admin');

set test.user_id = '33333333-3333-4333-8333-333333333333';
select t_assert(public.join_org_by_invite('ABCD1234') = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  'T09 join via invite sukses');
select t_assert(
  (select count(*) from org_members
   where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
     and user_id = '33333333-3333-4333-8333-333333333333') = 1,
  'T09 carol jadi member org A');
select t_assert(
  (select count(*) from org_invites where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 0,
  'T09 member non-admin tetap tak baca invite (tanpa recursion)');

set test.user_id = '22222222-2222-4222-8222-222222222222';
do $$
begin
  perform public.join_org_by_invite('ABCD1234');
  raise exception 'ASSERT GAGAL: T09 invite habis masih bisa dipakai';
exception when others then
  if sqlerrm not like '%INVITE_EXHAUSTED%' then
    raise;
  end if;
end $$;
select t_assert(
  not exists (
    select 1 from org_members
    where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
      and user_id = '22222222-2222-4222-8222-222222222222'
  ),
  'T09 join gagal tak meninggalkan membership (rollback)');

set test.user_id = '33333333-3333-4333-8333-333333333333';
select t_assert(public.join_org_by_invite('ABCD1234') = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  'T09 re-join member idempoten');
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert(
  (select used_count from org_invites
   where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 1,
  'T09 used_count idempoten = 1');
select t_assert(
  exists (select 1 from audit_logs
          where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
            and event = 'org_join'
            and actor_user_id = '33333333-3333-4333-8333-333333333333'),
  'T09 trigger audit org_join tercatat untuk carol');

-- anon tak boleh execute RPC invite
set role anon;
set test.user_id = '';
do $$
begin
  perform public.join_org_by_invite('ABCD1234');
  raise exception 'ASSERT GAGAL: T09 anon bisa execute join_org_by_invite';
exception when others then
  if sqlerrm not like '%permission denied%' then
    raise;
  end if;
end $$;
set role authenticated;

-- ===== T10: tx_sequences tak terbaca client langsung =====
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert((select count(*) from tx_sequences) = 0,
  'T10 tx_sequences tersembunyi dari client (RLS deny)');

-- ===== T11: wallet_balance mengikuti pemanggil (security_invoker) =====
select t_assert(
  (select balance from wallet_balance
   where wallet_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01') = 50000,
  'T11 saldo wallet A = 50000 (tanpa bocor auto-insert)');
set test.user_id = '22222222-2222-4222-8222-222222222222';
select t_assert((select count(*) from wallet_balance) = 1,
  'T11 bob hanya melihat saldo org B');
select t_assert(
  (select count(*) from wallet_balance
   where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 0,
  'T11 saldo org A tak terlihat bob');

-- ===== T12: list_org_members hanya untuk member =====
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert((select count(*) from public.list_org_members('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')) = 2,
  'T12 owner melihat 2 anggota org A');
set test.user_id = '99999999-9999-4999-8999-999999999999';
select t_assert((select count(*) from public.list_org_members('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')) = 0,
  'T12 non-member melihat 0 anggota');

-- ===== T13: kick_member guard =====
set test.user_id = '22222222-2222-4222-8222-222222222222';
do $$
begin
  perform public.kick_member('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '33333333-3333-4333-8333-333333333333');
  raise exception 'ASSERT GAGAL: T13 non-admin bisa kick';
exception when others then
  if sqlerrm not like '%NOT_ADMIN%' then raise; end if;
end $$;
-- dave admin di A (superuser, karena tanpa policy UPDATE role)
reset role;
insert into auth.users (id) values ('44444444-4444-4444-8444-444444444444') on conflict (id) do nothing;
insert into org_members (org_id, user_id, role) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '44444444-4444-4444-8444-444444444444', 'admin')
on conflict do nothing;
set role authenticated;
set test.user_id = '44444444-4444-4444-8444-444444444444';
do $$
begin
  perform public.kick_member('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '11111111-1111-4111-8111-111111111111');
  raise exception 'ASSERT GAGAL: T13 kick owner-terakhir lolos';
exception when others then
  if sqlerrm not like '%KICK_LAST_OWNER%' then raise; end if;
end $$;
set test.user_id = '11111111-1111-4111-8111-111111111111';
do $$
begin
  perform public.kick_member('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '11111111-1111-4111-8111-111111111111');
  raise exception 'ASSERT GAGAL: T13 kick diri sendiri lolos';
exception when others then
  if sqlerrm not like '%KICK_SELF%' then raise; end if;
end $$;
select public.kick_member('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '44444444-4444-4444-8444-444444444444');
select t_assert(
  not exists (select 1 from org_members
    where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
      and user_id = '44444444-4444-4444-8444-444444444444'),
  'T13 kick admin oleh owner lolos');
select public.kick_member('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '33333333-3333-4333-8333-333333333333');
select t_assert(
  not exists (select 1 from org_members
    where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
      and user_id = '33333333-3333-4333-8333-333333333333'),
  'T13 kick member oleh owner lolos');

-- ===== T14: delete_workspace guard + cascade =====
set test.user_id = '22222222-2222-4222-8222-222222222222';
do $$
begin
  perform public.delete_workspace('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1');
  raise exception 'ASSERT GAGAL: T14 non-owner bisa hapus';
exception when others then
  if sqlerrm not like '%NOT_OWNER%' then raise; end if;
end $$;
set test.user_id = '11111111-1111-4111-8111-111111111111';
insert into organizations (id, name, created_by)
values ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3', 'Org C',
        '11111111-1111-4111-8111-111111111111');
insert into org_members (org_id, user_id, role)
values ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3',
        '11111111-1111-4111-8111-111111111111', 'owner');
insert into wallets (id, org_id, name, type) values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeee03', 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3', 'Kas C', 'cash');
insert into transactions (id, org_id, type, amount, wallet_id, category, note, date, created_by) values
  ('dddddddd-dddd-4ddd-8ddd-ddddddddddd3', 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3',
   'out', 25000, 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee03', 'Makan', 'seed C', current_date,
   '11111111-1111-4111-8111-111111111111');
insert into budgets (org_id, category, month, limit_amount)
values ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3', 'Makan', '2026-09', 100000);
insert into org_invites (org_id, created_by, token_hash)
values ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3',
        '11111111-1111-4111-8111-111111111111', 'C3SEEDHASH000000000000000000000001');
select public.delete_workspace('cccccccc-cccc-4ccc-8ccc-ccccccccccc3');
select t_assert(
  not exists (select 1 from organizations where id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3'),
  'T14 org C terhapus');
select t_assert(
  not exists (select 1 from org_members where org_id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3'),
  'T14 members C cascade');
select t_assert(
  not exists (select 1 from wallets where org_id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3'),
  'T14 wallets C cascade');
select t_assert(
  not exists (select 1 from transactions where org_id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3'),
  'T14 transactions C cascade');
select t_assert(
  not exists (select 1 from budgets where org_id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3'),
  'T14 budgets C cascade');
select t_assert(
  not exists (select 1 from org_invites where org_id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3'),
  'T14 invites C cascade');

-- ===== T15: anon tak boleh execute RPC admin =====
set role anon;
set test.user_id = '';
do $$
begin
  perform public.kick_member('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '11111111-1111-4111-8111-111111111111');
  raise exception 'ASSERT GAGAL: T15 anon bisa kick_member';
exception when others then
  if sqlerrm not like '%permission denied%' then raise; end if;
end $$;
do $$
begin
  perform public.delete_workspace('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1');
  raise exception 'ASSERT GAGAL: T15 anon bisa delete_workspace';
exception when others then
  if sqlerrm not like '%permission denied%' then raise; end if;
end $$;
do $$
begin
  perform public.list_org_members('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1');
  raise exception 'ASSERT GAGAL: T15 anon bisa list_org_members';
exception when others then
  if sqlerrm not like '%permission denied%' then raise; end if;
end $$;
set role authenticated;

-- ===== T16-T20: We Space (migration_15) =====
-- User fiktif BARU (carol/dave sudah di-kick di T13, jangan dipakai).
reset role;
insert into auth.users (id) values
  ('55555555-5555-4555-8555-555555555555'),
  ('66666666-6666-4666-8666-666666666666')
on conflict (id) do nothing;
insert into org_members (org_id, user_id, role) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '55555555-5555-4555-8555-555555555555', 'member'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '66666666-6666-4666-8666-666666666666', 'admin')
on conflict do nothing;
set role authenticated;

-- T16: mode bebas (default) → member bisa insert.
set test.user_id = '55555555-5555-4555-8555-555555555555';
insert into transactions (org_id, type, amount, wallet_id, note, date)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 7000,
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01', 'T16 bebas-member', current_date);
select t_assert(exists (select 1 from transactions where note = 'T16 bebas-member'),
  'T16 bebas-member insert lolos');

-- T20a (duluankan): set_space_mode oleh member DITOLAK.
do $$
begin
  perform public.set_space_mode('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bendahara');
  raise exception 'ASSERT GAGAL: T20 member bisa set mode';
exception when others then
  if sqlerrm not like '%NOT_ADMIN%' then raise; end if;
end $$;

-- Owner set bendahara (jalur RPC resmi).
set test.user_id = '11111111-1111-4111-8111-111111111111';
select public.set_space_mode('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bendahara');
select t_assert((select space_mode from organizations where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 'bendahara',
  'T20 owner set bendahara lolos');
select t_assert(exists (select 1 from audit_logs
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1' and event = 'space_mode_change'),
  'T20 audit space_mode_change tertulis');

-- T17: mode bendahara → member insert DITOLAK RLS.
set test.user_id = '55555555-5555-4555-8555-555555555555';
do $$
begin
  insert into transactions (org_id, type, amount, wallet_id, note, date)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 7001,
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01', 'T17 harus-gagal', current_date);
  raise exception 'ASSERT GAGAL: T17 member bisa tulis di mode bendahara';
exception when others then
  if sqlerrm not like '%row-level security%' then raise; end if;
end $$;

-- T18: bendahara → owner + admin tetap bisa tulis.
set test.user_id = '11111111-1111-4111-8111-111111111111';
insert into transactions (org_id, type, amount, wallet_id, note, date)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 7002,
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01', 'T18 owner-bendahara', current_date);
set test.user_id = '66666666-6666-4666-8666-666666666666';
insert into transactions (org_id, type, amount, wallet_id, note, date)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 7003,
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01', 'T18 admin-bendahara', current_date);
select t_assert(exists (select 1 from transactions where note = 'T18 admin-bendahara'),
  'T18 admin tulis di bendahara lolos');

-- T19: baca member tetap jalan di mode bendahara.
set test.user_id = '55555555-5555-4555-8555-555555555555';
select t_assert((select count(*) from transactions
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') >= 3,
  'T19 member baca di bendahara lolos');

-- T20b: owner kembalikan bebas (bersih untuk test lain).
set test.user_id = '11111111-1111-4111-8111-111111111111';
select public.set_space_mode('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bebas');
select t_assert((select space_mode from organizations where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 'bebas',
  'T20 mode kembali bebas');

-- ===== T21: warn muncul saat capai 85% =====
set test.user_id = '11111111-1111-4111-8111-111111111111';
insert into budgets (org_id, category, month, limit_amount)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Makan', to_char(current_date, 'YYYY-MM'), 100000)
on conflict (org_id, category, month) do update set limit_amount = excluded.limit_amount;
insert into transactions (org_id, type, amount, category)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 85000, 'Makan');
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and month = to_char(current_date, 'YYYY-MM')
    and category = 'Makan' and level = 'warn') = 1,
  'T21 warn muncul di 85%');
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and month = to_char(current_date, 'YYYY-MM')
    and category = 'Makan' and level = 'breach') = 0,
  'T21 belum breach di 85%');

-- ===== T22: dedup warn tetap 1 =====
insert into transactions (org_id, type, amount, category)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 5000, 'Makan');
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and month = to_char(current_date, 'YYYY-MM')
    and category = 'Makan' and level = 'warn') = 1,
  'T22 dedup warn tetap 1');

-- ===== T23: breach muncul saat total >= 100% =====
insert into transactions (org_id, type, amount, category)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 20000, 'Makan');
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and month = to_char(current_date, 'YYYY-MM')
    and category = 'Makan' and level = 'breach') = 1,
  'T23 breach muncul di >=100%');
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and month = to_char(current_date, 'YYYY-MM')
    and category = 'Makan' and level = 'warn') = 1,
  'T23 warn tetap 1 setelah breach');

-- ===== T24: subkategori masuk grup lapis-atas =====
insert into budgets (org_id, category, month, limit_amount)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Minum', to_char(current_date, 'YYYY-MM'), 100000)
on conflict (org_id, category, month) do update set limit_amount = excluded.limit_amount;
insert into transactions (org_id, type, amount, category)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 90000, 'Minum > Kopi');
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and month = to_char(current_date, 'YYYY-MM')
    and category = 'Minum' and level = 'warn') = 1,
  'T24 warn grup Minum dari subkategori');
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and month = to_char(current_date, 'YYYY-MM')
    and category = 'Minum > Kopi') = 0,
  'T24 tanpa grup sendiri untuk subkategori');

-- ===== T25: negatif (in/transfer tak picu, tulis langsung ditolak, lintas-org kosong) =====
insert into transactions (org_id, type, amount, category)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'in', 90000, 'Makan');
insert into transactions (org_id, type, amount, category)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'transfer', 90000, 'Makan');
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and month = to_char(current_date, 'YYYY-MM')
    and category = 'Makan') = 2,
  'T25 in/transfer tak tambah baris');
do $$
begin
  insert into budget_alerts (org_id, month, category, level, spent, limit_amount)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', to_char(current_date, 'YYYY-MM'), 'Makan', 'warn', 1, 1);
  raise exception 'ASSERT GAGAL: T25 client insert budget_alerts lolos';
exception when sqlstate '42501' then null;
end $$;
set test.user_id = '22222222-2222-4222-8222-222222222222';
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 0,
  'T25 alerts org A tak terbaca org B');
set test.user_id = '11111111-1111-4111-8111-111111111111';

-- ===== T26: fail-open (kategori tanpa budget) =====
insert into transactions (org_id, type, amount, category)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 50000, 'NoBudgetT26');
select t_assert(exists (select 1 from transactions
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1' and category = 'NoBudgetT26' and amount = 50000),
  'T26 insert tanpa budget tetap lolos');
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and month = to_char(current_date, 'YYYY-MM')
    and category = 'NoBudgetT26') = 0,
  'T26 tanpa baris alert untuk kategori tanpa budget');

-- ===== T27: warn_pct custom dihormati =====
insert into budgets (org_id, category, month, limit_amount, warn_pct)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Jajan', to_char(current_date, 'YYYY-MM'), 100000, 50)
on conflict (org_id, category, month) do update set limit_amount = excluded.limit_amount, warn_pct = excluded.warn_pct;
insert into transactions (org_id, type, amount, category)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 55000, 'Jajan');
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and month = to_char(current_date, 'YYYY-MM')
    and category = 'Jajan' and level = 'warn') = 1,
  'T27 warn custom 50% muncul di 55%');
select t_assert((select count(*) from budget_alerts
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and month = to_char(current_date, 'YYYY-MM')
    and category = 'Jajan' and level = 'breach') = 0,
  'T27 belum breach di 55%');

-- ===== T28: kuota auto-track 150/bln free (migration_17) =====
-- Bersihkan 10 baris T06 dulu (assert-nya sudah lewat) supaya rate limit
-- 10/60 dtk (migration_11) tak ikut menembak: baris uji dimundurkan 1 jam.
reset role;
delete from transactions
where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
  and source_package = 'id.dana';
set role authenticated;
set test.user_id = '11111111-1111-4111-8111-111111111111';
insert into transactions (org_id, type, amount, source_package, date, created_at)
select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'in', 1000, 'id.dana',
       current_date, now() - interval '1 hour'
from generate_series(1, 150);
select t_assert((select count(*) from transactions
  where org_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and source_package is not null
    and date >= date_trunc('month', current_date)::date) = 150,
  'T28 150 auto bulan ini tersimpan');
do $$
begin
  insert into transactions (org_id, type, amount, source_package, date, created_at)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'in', 1000, 'id.dana',
          current_date, now() - interval '1 hour');
  raise exception 'ASSERT GAGAL: T28 auto ke-151 lolos';
exception when others then
  if sqlerrm not like '%QUOTA_EXCEEDED%' then raise; end if;
end $$;
-- Manual (tanpa source_package) tetap bebas kuota.
insert into transactions (org_id, type, amount)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'in', 1000);
select t_assert(
  (public.check_quota('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'auto')->>'allowed')::boolean = false
  and (public.check_quota('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'auto')->>'used')::int = 150
  and (public.check_quota('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'auto')->>'plan') = 'free',
  'T28 check_quota auto jujur');

-- ===== T29: kuota anggota 3/org free + RPC (migration_17) =====
-- Org A sudah 3 anggota (alice+5555+6666): erin ditolak trigger.
reset role;
insert into auth.users (id) values ('77777777-7777-4777-8777-777777777777')
on conflict (id) do nothing;
set role authenticated;
set test.user_id = '11111111-1111-4111-8111-111111111111';
do $$
begin
  insert into org_members (org_id, user_id, role)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
          '77777777-7777-4777-8777-777777777777', 'member');
  raise exception 'ASSERT GAGAL: T29 anggota ke-4 lolos';
exception when others then
  if sqlerrm not like '%QUOTA_EXCEEDED%' then raise; end if;
end $$;
select t_assert(
  (public.check_quota('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'members')->>'allowed')::boolean = false
  and (public.check_quota('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'members')->>'used')::int = 3,
  'T29 check_quota members jujur');
-- Bukan member → NOT_MEMBER; kind asing → fail-closed.
set test.user_id = '77777777-7777-4777-8777-777777777777';
do $$
begin
  perform public.check_quota('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'auto');
  raise exception 'ASSERT GAGAL: T29 non-member bisa check_quota';
exception when others then
  if sqlerrm not like '%NOT_MEMBER%' then raise; end if;
end $$;
set test.user_id = '11111111-1111-4111-8111-111111111111';
do $$
begin
  perform public.check_quota('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'emas');
  raise exception 'ASSERT GAGAL: T29 kind asing lolos';
exception when others then
  if sqlerrm not like '%QUOTA_UNKNOWN_KIND%' then raise; end if;
end $$;
-- Pro bebas: org B naik pro → tambah 2 anggota lolos.
reset role;
update organizations set plan = 'pro'
where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
insert into auth.users (id) values
  ('88888888-8888-4888-8888-888888888888'),
  ('12121212-1212-4121-8121-121212121212')
on conflict (id) do nothing;
set role authenticated;
set test.user_id = '22222222-2222-4222-8222-222222222222';
insert into org_members (org_id, user_id, role) values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', '88888888-8888-4888-8888-888888888888', 'member'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', '12121212-1212-4121-8121-121212121212', 'member');
select t_assert((select count(*) from public.list_org_members(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2')) = 3,
  'T29 org pro boleh 3+ anggota');
select t_assert(
  (public.check_quota('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'members')->>'allowed')::boolean = true,
  'T29 check_quota pro allowed');

-- ===== T30: kuota workspace 2/user free (migration_17) =====
-- alice ikut 1 org (A; C sudah dihapus T14): RPC jujur lalu batas menembak.
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert(
  (public.check_quota('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'workspaces')->>'allowed')::boolean = true
  and (public.check_quota('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'workspaces')->>'used')::int = 1,
  'T30 check_quota workspaces jujur');
insert into organizations (id, name, created_by)
values ('dddddddd-dddd-4ddd-8ddd-ddddddddddd4', 'Org D',
        '11111111-1111-4111-8111-111111111111');
insert into org_members (org_id, user_id, role)
values ('dddddddd-dddd-4ddd-8ddd-ddddddddddd4',
        '11111111-1111-4111-8111-111111111111', 'owner');
select t_assert(
  (public.check_quota('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'workspaces')->>'allowed')::boolean = false,
  'T30 penuh di 2 workspace');
do $$
begin
  insert into organizations (id, name, created_by)
  values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeee05', 'Org E',
          '11111111-1111-4111-8111-111111111111');
  raise exception 'ASSERT GAGAL: T30 workspace ke-3 lolos';
exception when others then
  if sqlerrm not like '%QUOTA_EXCEEDED%' then raise; end if;
end $$;

-- ===== T31: month_mix agregat eksak + wallet filter (migration_18) =====
-- Bulan fiktif 2020-01 (terisolasi dari fixture lain).
set test.user_id = '11111111-1111-4111-8111-111111111111';
insert into transactions (org_id, type, amount, category, wallet_id, date)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'in', 100, 'Gaji', null, '2020-01-15'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 40, 'Makan', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01', '2020-01-15'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'out', 10, 'Tabungan', null, '2020-01-20');
select t_assert(
  (public.month_mix('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2020-01')->>'total_n')::int = 3,
  'T31 total_n 3 baris');
select t_assert(
  (select coalesce(sum((r->>'s')::double precision), 0) from jsonb_array_elements(
    public.month_mix('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2020-01')->'rows') r
   where r->>'t' = 'in') = 100,
  'T31 in_sum eksak');
select t_assert(
  (select coalesce(sum((r->>'s')::double precision), 0) from jsonb_array_elements(
    public.month_mix('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2020-01',
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01')->'rows') r) = 40,
  'T31 filter dompet hanya baris cocok');
-- Bukan member → NOT_MEMBER; anon → permission denied; bulan rusak → MIX_BAD_MONTH.
set test.user_id = '77777777-7777-4777-8777-777777777777';
do $$
begin
  perform public.month_mix('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2020-01');
  raise exception 'ASSERT GAGAL: T31 non-member bisa month_mix';
exception when others then
  if sqlerrm not like '%NOT_MEMBER%' then raise; end if;
end $$;
set role anon;
do $$
begin
  perform public.month_mix('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2020-01');
  raise exception 'ASSERT GAGAL: T31 anon bisa month_mix';
exception when others then
  if sqlerrm not like '%permission denied%' then raise; end if;
end $$;
set role authenticated;
set test.user_id = '11111111-1111-4111-8111-111111111111';
do $$
begin
  perform public.month_mix('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bukan-bulan');
  raise exception 'ASSERT GAGAL: T31 bulan rusak lolos';
exception when others then
  if sqlerrm not like '%MIX_BAD_MONTH%' then raise; end if;
end $$;

-- ===== T32: touch_heartbeat tulis + prune + anon ditolak (migration_18) =====
select t_assert(public.touch_heartbeat('t32') is not null,
  'T32 touch kembalikan waktu');
-- heartbeat deny-all untuk client: keberadaan baris dicek superuser.
reset role;
select t_assert(exists (select 1 from heartbeat
  where source = 't32'
    and user_id = '11111111-1111-4111-8111-111111111111'),
  'T32 baris heartbeat tercatat');
-- Baris tua (>30 hari) ikut ter-prune saat touch.
insert into heartbeat (pinged_at, source)
values (now() - interval '40 days', 'tua-t32');
set role authenticated;
set test.user_id = '11111111-1111-4111-8111-111111111111';
select public.touch_heartbeat('t32b');
reset role;
select t_assert(not exists (select 1 from heartbeat where source = 'tua-t32'),
  'T32 prune baris tua');
set role authenticated;
set role anon;
do $$
begin
  perform public.touch_heartbeat('anon-t32');
  raise exception 'ASSERT GAGAL: T32 anon bisa touch';
exception when others then
  if sqlerrm not like '%permission denied%' then raise; end if;
end $$;
set role authenticated;
set test.user_id = '11111111-1111-4111-8111-111111111111';

-- ===== T33: realtime ready (migration_19) =====
-- Replica identity FULL selalu bisa dicek di postgres mana pun.
select t_assert((select relreplident = 'f' from pg_class
  where relname = 'transactions'),
  'T33 replica full transactions');
select t_assert((select relreplident = 'f' from pg_class
  where relname = 'org_members'),
  'T33 replica full org_members');
select t_assert((select relreplident = 'f' from pg_class
  where relname = 'wallets'),
  'T33 replica full wallets');
select t_assert((select relreplident = 'f' from pg_class
  where relname = 'budgets'),
  'T33 replica full budgets');
-- Publication hanya ada di Supabase asli: tak ada = SKIP jujur.
do $$
begin
  if not exists (select 1 from pg_publication
                 where pubname = 'supabase_realtime') then
    raise notice 'SKIP T33 publication (bukan Supabase)';
    return;
  end if;
  if (select count(*) from pg_publication_tables
      where pubname = 'supabase_realtime'
        and tablename in
          ('transactions', 'org_members', 'wallets', 'budgets')) <> 4 then
    raise exception 'ASSERT GAGAL: T33 publication tak lengkap';
  end if;
end $$;

-- ===== T34: entitlement VIP + limit wallet/budget/AI (migration_20) =====
-- Fixture: 2 user + 2 org + 3 kode VIP (superuser; vip_codes RPC-only,
-- client insert langsung pasti 42501 sehingga seed wajib superuser).
reset role;
insert into auth.users (id) values
  ('f0000000-0000-4000-8000-00000000000f'),
  ('60000000-0000-4000-8000-000000000006')
on conflict (id) do nothing;
insert into vip_codes (code_hash, duration_days, max_uses, note) values
  (encode(sha256(convert_to(upper(trim(both from 'SSR-VIP-T34A')), 'UTF8')), 'hex'), 30, 5, 't34 multi'),
  (encode(sha256(convert_to(upper(trim(both from 'SSR-VIP-NORM-34')), 'UTF8')), 'hex'), null, 5, 't34 norm'),
  (encode(sha256(convert_to(upper(trim(both from 'SSR-VIP-ONCE-34')), 'UTF8')), 'hex'), 30, 1, 't34 once')
on conflict (code_hash) do nothing;
set role authenticated;

-- T34b: kode salah → VIP_INVALID (tanpa ubah state).
set test.user_id = '11111111-1111-4111-8111-111111111111';
do $$
begin
  perform public.redeem_vip_code('KODE-SALAH-T34');
  raise exception 'ASSERT GAGAL: T34b kode salah lolos';
exception when others then
  if sqlerrm not like '%VIP_INVALID%' then raise; end if;
end $$;

-- T34a: redeem happy → entitlement ada + plan_status pro via vip.
select public.redeem_vip_code('SSR-VIP-T34A');
-- user_entitlements RPC-only: keberadaan baris dicek superuser (pola T32).
reset role;
select t_assert(
  (select count(*) from user_entitlements
   where user_id = '11111111-1111-4111-8111-111111111111'
     and source = 'vip_code'
     and source_ref = encode(sha256(convert_to(upper(trim(both from 'SSR-VIP-T34A')), 'UTF8')), 'hex')) = 1,
  'T34a entitlement tercatat');
set role authenticated;
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert(
  (public.plan_status('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')->>'plan') = 'pro'
  and (public.plan_status('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')->>'source') = 'vip',
  'T34a plan_status pro via vip');
select t_assert(public.org_plan('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') = 'pro',
  'T34a org_plan pro via owner ber-entitlement');

-- T34a2: normalisasi — lowercase + spasi → sukses.
set test.user_id = '22222222-2222-4222-8222-222222222222';
select public.redeem_vip_code('  ssr-vip-norm-34  ');
reset role;
select t_assert(
  (select count(*) from user_entitlements
   where user_id = '22222222-2222-4222-8222-222222222222'
     and source_ref = encode(sha256(convert_to(upper(trim(both from 'SSR-VIP-NORM-34')), 'UTF8')), 'hex')) = 1,
  'T34a2 redeem lowercase+spasi sukses');
set role authenticated;

-- T34c: max_uses=1 dipakai 2 user → kedua VIP_EXHAUSTED.
set test.user_id = '33333333-3333-4333-8333-333333333333';
select public.redeem_vip_code('SSR-VIP-ONCE-34');
set test.user_id = '22222222-2222-4222-8222-222222222222';
do $$
begin
  perform public.redeem_vip_code('SSR-VIP-ONCE-34');
  raise exception 'ASSERT GAGAL: T34c redeem kedua lolos';
exception when others then
  if sqlerrm not like '%VIP_EXHAUSTED%' then raise; end if;
end $$;
reset role;
select t_assert(
  (select used_count from vip_codes
   where code_hash = encode(sha256(convert_to(upper(trim(both from 'SSR-VIP-ONCE-34')), 'UTF8')), 'hex')) = 1,
  'T34c used_count tetap 1');
set role authenticated;
set test.user_id = '22222222-2222-4222-8222-222222222222';

-- T34d: idempoten — redeem sama 2x, used_count tetap 1 + tetap 1 baris.
set test.user_id = '11111111-1111-4111-8111-111111111111';
select public.redeem_vip_code('SSR-VIP-T34A');
reset role;
select t_assert(
  (select used_count from vip_codes
   where code_hash = encode(sha256(convert_to(upper(trim(both from 'SSR-VIP-T34A')), 'UTF8')), 'hex')) = 1,
  'T34d redeem ulang tak increment');
select t_assert(
  (select count(*) from user_entitlements
   where user_id = '11111111-1111-4111-8111-111111111111'
     and source = 'vip_code'
     and source_ref = encode(sha256(convert_to(upper(trim(both from 'SSR-VIP-T34A')), 'UTF8')), 'hex')) = 1,
  'T34d tetap 1 entitlement');
set role authenticated;
set test.user_id = '11111111-1111-4111-8111-111111111111';

-- T34e: entitlement lampau → plan free (org milik frank, insert expired via superuser).
set test.user_id = 'f0000000-0000-4000-8000-00000000000f';
insert into organizations (id, name, created_by)
values ('f0000000-0000-4000-8000-0000000000f0', 'Org F',
        'f0000000-0000-4000-8000-00000000000f');
insert into org_members (org_id, user_id, role)
values ('f0000000-0000-4000-8000-0000000000f0',
        'f0000000-0000-4000-8000-00000000000f', 'owner');
reset role;
insert into user_entitlements (user_id, plan, expires_at, source, source_ref)
values ('f0000000-0000-4000-8000-00000000000f', 'pro', now() - interval '1 day', 'manual', 't34e');
set role authenticated;
set test.user_id = 'f0000000-0000-4000-8000-00000000000f';
select t_assert(public.org_plan('f0000000-0000-4000-8000-0000000000f0') = 'free',
  'T34e entitlement lampau → org_plan free');
select t_assert(
  (public.plan_status('f0000000-0000-4000-8000-0000000000f0')->>'plan') = 'free',
  'T34e plan_status free saat entitlement lampau');

-- T34f-setup: org free milik grace (tanpa entitlement) untuk uji blokir g/h/i.
set test.user_id = '60000000-0000-4000-8000-000000000006';
insert into organizations (id, name, created_by)
values ('60000000-0000-4000-8000-00000000060d', 'Org G',
        '60000000-0000-4000-8000-000000000006');
insert into org_members (org_id, user_id, role)
values ('60000000-0000-4000-8000-00000000060d',
        '60000000-0000-4000-8000-000000000006', 'owner');
select t_assert(public.org_plan('60000000-0000-4000-8000-00000000060d') = 'free',
  'T34f org G free sebelum redeem');

-- T34g: wallet ke-8 free → QUOTA_EXCEEDED.
insert into wallets (org_id, name)
select '60000000-0000-4000-8000-00000000060d', 'W' || g
from generate_series(1, 7) g;
select t_assert(
  (public.check_quota('60000000-0000-4000-8000-00000000060d', 'wallets')->>'allowed')::boolean = false
  and (public.check_quota('60000000-0000-4000-8000-00000000060d', 'wallets')->>'used')::int = 7,
  'T34g check_quota wallets jujur di 7');
do $$
begin
  insert into wallets (org_id, name)
  values ('60000000-0000-4000-8000-00000000060d', 'W8');
  raise exception 'ASSERT GAGAL: T34g wallet ke-8 lolos';
exception when others then
  if sqlerrm not like '%QUOTA_EXCEEDED%' then raise; end if;
end $$;

-- T34h: bucket ke-8 baru ditolak, edit existing (UPSERT pola budget_service) lolos.
insert into budgets (org_id, category, month, limit_amount)
select '60000000-0000-4000-8000-00000000060d', 'B' || g, to_char(current_date, 'YYYY-MM'), 10000
from generate_series(1, 7) g;
do $$
begin
  insert into budgets (org_id, category, month, limit_amount)
  values ('60000000-0000-4000-8000-00000000060d', 'B8', to_char(current_date, 'YYYY-MM'), 10000);
  raise exception 'ASSERT GAGAL: T34h bucket ke-8 lolos';
exception when others then
  if sqlerrm not like '%QUOTA_EXCEEDED%' then raise; end if;
end $$;
insert into budgets (org_id, category, month, limit_amount)
values ('60000000-0000-4000-8000-00000000060d', 'B1', to_char(current_date, 'YYYY-MM'), 20000)
on conflict (org_id, category, month) do update set limit_amount = excluded.limit_amount;
select t_assert(
  (select limit_amount from budgets
   where org_id = '60000000-0000-4000-8000-00000000060d'
     and category = 'B1' and month = to_char(current_date, 'YYYY-MM')) = 20000,
  'T34h edit bucket existing lolos');

-- T34i: 30x record_ai_usage → check_quota ai allowed=false.
select t_assert(
  (public.check_quota('60000000-0000-4000-8000-00000000060d', 'ai')->>'allowed')::boolean = true,
  'T34i ai allowed sebelum pakai');
do $$
declare i int;
begin
  for i in 1..30 loop
    perform public.record_ai_usage('60000000-0000-4000-8000-00000000060d', 'chat');
  end loop;
end $$;
select t_assert(
  (public.check_quota('60000000-0000-4000-8000-00000000060d', 'ai')->>'allowed')::boolean = false
  and (public.check_quota('60000000-0000-4000-8000-00000000060d', 'ai')->>'used')::int = 30
  and (public.check_quota('60000000-0000-4000-8000-00000000060d', 'ai')->>'limit')::int = 30,
  'T34i ai mentok di 30');

-- T34f: owner redeem → org pro; wallet + budget ke-8 lolos (Pro).
select public.redeem_vip_code('SSR-VIP-T34A');
select t_assert(public.org_plan('60000000-0000-4000-8000-00000000060d') = 'pro',
  'T34f org_plan pro via VIP-owner');
select t_assert(
  (public.plan_status('60000000-0000-4000-8000-00000000060d')->>'source') = 'vip',
  'T34f plan_status source vip');
insert into wallets (org_id, name)
values ('60000000-0000-4000-8000-00000000060d', 'W8');
select t_assert(exists (select 1 from wallets
  where org_id = '60000000-0000-4000-8000-00000000060d' and name = 'W8'),
  'T34g Pro lolos wallet ke-8');
insert into budgets (org_id, category, month, limit_amount)
values ('60000000-0000-4000-8000-00000000060d', 'B8', to_char(current_date, 'YYYY-MM'), 10000);
select t_assert(exists (select 1 from budgets
  where org_id = '60000000-0000-4000-8000-00000000060d'
    and category = 'B8' and month = to_char(current_date, 'YYYY-MM')),
  'T34h Pro lolos bucket ke-8');

-- T34j: client-deny — tabel RPC-only tak terbaca client meski baris ada
-- (RLS tanpa policy = 0 baris, pola T10; tulis = 42501, pola T03/T07).
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert((select count(*) from vip_codes) = 0,
  'T34j vip_codes tak terbaca client (RPC-only)');
select t_assert((select count(*) from user_entitlements) = 0,
  'T34j user_entitlements tak terbaca client (RPC-only)');
select t_assert((select count(*) from ai_usage) = 0,
  'T34j ai_usage tak terbaca client (RPC-only)');
do $$
begin
  insert into user_entitlements (user_id, plan, source)
  values ('11111111-1111-4111-8111-111111111111', 'pro', 'vip_code');
  raise exception 'ASSERT GAGAL: T34j client INSERT user_entitlements lolos';
exception when sqlstate '42501' then null;
end $$;
-- Grant: RPC boleh authenticated, anon ditolak; trigger-fn revoke semua.
select t_assert(has_function_privilege('authenticated', 'public.redeem_vip_code(text)', 'execute'),
  'T34j authenticated boleh execute redeem');
select t_assert(not has_function_privilege('anon', 'public.redeem_vip_code(text)', 'execute'),
  'T34j anon tak boleh execute redeem');
select t_assert(not has_function_privilege('authenticated', 'public.enforce_wallet_quota()', 'execute'),
  'T34j trigger-fn revoke authenticated');
-- NULL-kind fail-closed (semantik fix d3480bf).
do $$
begin
  perform public.check_quota('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', null);
  raise exception 'ASSERT GAGAL: T34j kind NULL lolos';
exception when others then
  if sqlerrm not like '%QUOTA_UNKNOWN_KIND%' then raise; end if;
end $$;
-- plan_status fail-closed untuk non-member.
set test.user_id = '77777777-7777-4777-8777-777777777777';
do $$
begin
  perform public.plan_status('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1');
  raise exception 'ASSERT GAGAL: T34j non-member bisa plan_status';
exception when others then
  if sqlerrm not like '%NOT_MEMBER%' then raise; end if;
end $$;
-- anon: RPC revoke menembak permission denied (pola T09/T15).
set role anon;
set test.user_id = '';
do $$
begin
  perform public.redeem_vip_code('SSR-VIP-T34A');
  raise exception 'ASSERT GAGAL: T34j anon bisa redeem';
exception when others then
  if sqlerrm not like '%permission denied%' then raise; end if;
end $$;
do $$
begin
  perform public.plan_status('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1');
  raise exception 'ASSERT GAGAL: T34j anon bisa plan_status';
exception when others then
  if sqlerrm not like '%permission denied%' then raise; end if;
end $$;
set role authenticated;
set test.user_id = '11111111-1111-4111-8111-111111111111';

-- ===== Selesai =====
reset role;
select t_assert(true, 'SELESAI semua tes lulus');
