-- Suite test RLS SSR SPACE — dijalankan run.sh SETELAH schema + migration_02..11.
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

-- ===== Selesai =====
reset role;
select t_assert(true, 'SELESAI semua tes lulus');
