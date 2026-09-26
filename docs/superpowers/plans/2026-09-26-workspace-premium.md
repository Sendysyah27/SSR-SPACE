# Workspace Premium Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Layar detail workspace premium (daftar anggota + keluarkan + hapus workspace) dengan guard server-side via RPC.

**Architecture:** 3 RPC SECURITY DEFINER di `migration_14` (list/kick/delete, tanpa policy org_members baru agar nol risiko rekursi); service Dart tipis; 1 layar baru + 1 dialog PIN bersama; copy via `strings.dart` ID/EN.

**Tech Stack:** Flutter stable, Supabase Postgres RLS + PL/pgSQL, `flutter test`, suite `supabase/test/run.sh`.

**Spec:** `docs/superpowers/specs/2026-09-26-workspace-premium-design.md`

## Global Constraints

- Bahasa UI Indonesia + Inggris via `tr()`; copy baru hanya di `lib/utils/strings.dart`.
- Nominal pakai `amt()`; tabular via tema; warna dari `SsrColors` (zamrud/bata/kertas).
- Policy SELECT `org_members` TIDAK BOLEH subquery `org_members` (rekursi).
- `flutter analyze` 0 issue (fatal bahkan info); `build()` layar < 50 baris.
- Re-use widget `lib/widgets/` (SectionCard, StatusChip, PrimaryButton, PinField); nominal lewat `amt()`.
- Antislop mode DURING + Delivery Gate sebelum APK; dial ENERGY 2 / RHYTHM 2 / MOTION 2; motif garis ledger; tanpa em dash di copy.
- Migration baru, jangan edit history; user jalankan manual di SQL Editor.

---

## File Structure

- Buat: `supabase/migration_14_workspace_admin.sql` (3 RPC).
- Ubah: `supabase/test/rls_test.sql` (T12-T15). `run.sh` tak diubah (glob sudah mencakup `migration_14`; `migration_13` tetap skip).
- Buat: `lib/services/workspace_service.dart` (members/kick/remove via RPC).
- Buat: `lib/screens/workspace/workspace_detail_screen.dart` (hero + anggota + danger).
- Buat: `lib/widgets/pin_dialog.dart` (`askPinDialog`, dipakai danger zone).
- Ubah: `lib/screens/workspace/org_switcher_screen.dart` (tombol gear per baris -> detail; ketuk baris TETAP pilih workspace).
- Ubah: `lib/utils/strings.dart` (kunci `wsm_*`).
- Ubah: `AUDIT.md` + `AGENTS.md` (changelog lokal, gabung commit ini).

---

### Task 1: migration_14 (3 RPC)

**Files:**
- Create: `supabase/migration_14_workspace_admin.sql`

**Interfaces:**
- Produces: `public.list_org_members(uuid) returns table(user_id uuid, role text)`; `public.kick_member(uuid, uuid) returns void`; `public.delete_workspace(uuid) returns void`. Semua `security definer`, `set search_path = public`, `grant execute ... to authenticated`, revoke dari public/anon (ikut pola migration_12).

- [ ] **Step 1: Tulis migration_14**

```sql
-- SSR SPACE migration 14: admin workspace (list/kick/delete via RPC).
-- Jalankan di Supabase Dashboard -> SQL Editor SETELAH migration_13.

-- Daftar anggota: hanya member org tsb (nama/email TIDAK diekspos;
-- client tampilkan ID terpotong + peran + penanda Kamu).
create or replace function public.list_org_members(p_org_id uuid)
returns table (user_id uuid, role text)
language sql
security definer
set search_path = public
as $$
  select m.user_id, m.role from org_members m
  where m.org_id = p_org_id
    and exists (
      select 1 from org_members me
      where me.org_id = p_org_id and me.user_id = auth.uid()
    )
  order by m.role, m.user_id;
$$;

revoke execute on function public.list_org_members(uuid) from public, anon;
grant execute on function public.list_org_members(uuid) to authenticated;

-- Keluarkan anggota: pemanggil owner/admin; tolak target owner terakhir;
-- tolak keluarkan diri sendiri (kode KICK_SELF / KICK_LAST_OWNER / NOT_ADMIN).
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
  delete from org_members where org_id = p_org_id and user_id = p_user_id;
end $$;

revoke execute on function public.kick_member(uuid, uuid) from public, anon;
grant execute on function public.kick_member(uuid, uuid) to authenticated;

-- Hapus workspace: hanya owner/creator; cascade hapus semua data org
-- (FK on delete cascade sudah ada di semua tabel org).
create or replace function public.delete_workspace(p_org_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_myrole text;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  select role into v_myrole from org_members
  where org_id = p_org_id and user_id = v_uid;
  if v_myrole is distinct from 'owner' then
    raise exception 'NOT_OWNER';
  end if;
  delete from organizations where id = p_org_id;
end $$;

revoke execute on function public.delete_workspace(uuid) from public, anon;
grant execute on function public.delete_workspace(uuid) to authenticated;
```

- [ ] **Step 2: Commit migration saja (tanpa test dulu)**

```bash
git add supabase/migration_14_workspace_admin.sql
git commit -m "feat: migration_14 RPC admin workspace (list/kick/delete)"
```

### Task 2: Assert RLS T12-T15

**Files:**
- Modify: `supabase/test/rls_test.sql` (sisip sebelum `-- ===== Selesai =====`)
- Test: `SSR_RLS_DB_URL=postgresql://... bash supabase/test/run.sh` (atau tunggu CI `rls-test.yml`)

**Interfaces:**
- Consumes: fixture suite (alice `11111111-...` owner org A `aaaaaaaa-...-aaa1`, bob `2222...` member?, carol `3333...`). Cek role bob/carol di file sebelum tulis (lihat baris T01-T09).
- Produces: suite tetap hijau + 4 assert baru.

- [ ] **Step 1: Tulis T12-T15 (pola ikut T09: `t_assert` + blok anon `permission denied`)**

```sql
-- ===== T12: list_org_members hanya untuk member =====
set test.user_id = '11111111-1111-4111-8111-111111111111';
select t_assert((select count(*) from public.list_org_members('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')) >= 1,
  'T12 owner bisa list anggota');
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
-- (Setup T13b di suite: jadikan bob admin org A, atau pakai org B bila bob admin di sana;
--  lalu kick carol (member) -> lolos, dan kick owner-terakhir -> KICK_LAST_OWNER.)
```

- [ ] **Step 2: Jalankan suite RLS lokal; harus hijau**

Run: `SSR_RLS_DB_URL=postgresql://postgres:postgres@localhost:5432/postgres bash supabase/test/run.sh`
Expected: `== SUKSES: suite RLS lulus`

- [ ] **Step 3: Commit test**

```bash
git add supabase/test/rls_test.sql
git commit -m "test: assert RLS T12-T15 workspace admin"
```

### Task 3: workspace_service.dart

**Files:**
- Create: `lib/services/workspace_service.dart`

**Interfaces:**
- Produces: `WorkspaceService().members(orgId) -> Future<List<OrgMember>>`; `kickMember(orgId, userId)`; `deleteWorkspace(orgId)`. `OrgMember{userId, role, isYou}` murni di file sama. Error PostgrestException diteruskan (UI petakan kode: NOT_ADMIN/KICK_LAST_OWNER/NOT_OWNER).

- [ ] **Step 1: Tulis service (ikut pola WalletService/InviteService: rpc via SupabaseConfig.client)**

```dart
import 'package:ssr_space/services/supabase_config.dart';

class OrgMember {
  final String userId;
  final String role;
  const OrgMember({required this.userId, required this.role});
}

class WorkspaceService {
  Future<List<OrgMember>> members(String orgId) async {
    final rows = await SupabaseConfig.client.rpc(
      'list_org_members',
      params: {'p_org_id': orgId},
    );
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    return List<Map<String, dynamic>>.from(rows)
        .map((m) => OrgMember(
              userId: m['user_id'].toString(),
              role: (m['role'] ?? 'member').toString(),
            ))
        .toList()
      ..sort((a, b) {
        if ((a.userId == uid) != (b.userId == uid)) {
          return a.userId == uid ? -1 : 1;
        }
        return a.role.compareTo(b.role);
      });
  }

  Future<void> kickMember(String orgId, String userId) async {
    await SupabaseConfig.client.rpc(
      'kick_member',
      params: {'p_org_id': orgId, 'p_user_id': userId},
    );
  }

  Future<void> deleteWorkspace(String orgId) async {
    await SupabaseConfig.client.rpc(
      'delete_workspace',
      params: {'p_org_id': orgId},
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/workspace_service.dart
git commit -m "feat: workspace_service (members/kick/delete via RPC)"
```

### Task 4: pin_dialog + strings

**Files:**
- Create: `lib/widgets/pin_dialog.dart`
- Modify: `lib/utils/strings.dart` (kunci `wsm_*` di bawah, ID + EN)

**Interfaces:**
- Produces: `Future<bool> askPinDialog(BuildContext context)` (true bila PIN benar; false bila batal/salah; pakai SessionService.verifyPin + PinField, ikut pola budgets_screen).

- [ ] **Step 1: Tulis strings (tempel setelah blok `org_*`)**

```dart
'wsm_members': {'id': 'Anggota', 'en': 'Members'},
'wsm_you': {'id': 'Kamu', 'en': 'You'},
'wsm_kick': {'id': 'Keluarkan', 'en': 'Remove'},
'wsm_kick_title': {'id': 'Keluarkan anggota?', 'en': 'Remove member?'},
'wsm_kick_body': {'id': 'Aksesnya ke buku kas ini langsung putus.', 'en': 'Their access to this ledger ends immediately.'},
'wsm_kick_last': {'id': 'Tak bisa keluarkan pemilik terakhir.', 'en': 'Cannot remove the last owner.'},
'wsm_kick_denied': {'id': 'Hanya pemilik/admin.', 'en': 'Owners/admins only.'},
'wsm_danger': {'id': 'Zona danger', 'en': 'Danger zone'},
'wsm_delete': {'id': 'Hapus workspace', 'en': 'Delete workspace'},
'wsm_delete_body': {'id': 'Semua dompet, transaksi, dan data ikut terhapus. Ketik nama workspace untuk konfirmasi.', 'en': 'All wallets, transactions, and data go with it. Type the workspace name to confirm.'},
'wsm_delete_hint': {'id': 'Ketik nama workspace', 'en': 'Type workspace name'},
'wsm_deleted': {'id': 'Workspace dihapus.', 'en': 'Workspace deleted.'},
'wsm_err': {'id': 'Gagal. Periksa koneksi.', 'en': 'Failed. Check your connection.'},
'wsm_detail': {'id': 'Kelola', 'en': 'Manage'},
```

- [ ] **Step 2: Tulis pin_dialog.dart, commit keduanya**

```bash
git add lib/widgets/pin_dialog.dart lib/utils/strings.dart
git commit -m "feat: pin_dialog bersama + copy workspace detail"
```

### Task 5: WorkspaceDetailScreen + hook gear

**Files:**
- Create: `lib/screens/workspace/workspace_detail_screen.dart`
- Modify: `lib/screens/workspace/org_switcher_screen.dart` (import detail; `_OrgRow` tambah `IconButton` gear -> detail; ketuk baris TETAP `_select`)

**Interfaces:**
- Consumes: Task 3 (WorkspaceService), Task 4 (askPinDialog, strings).
- Produces: layar < 50 baris per build; hero gelap (nama + chip peran + jumlah anggota); daftar ledger; danger zone; undang -> buka InviteScreen yang sudah ada (cek path `lib/screens/workspace/`).

- [ ] **Step 1: Tulis layar (state: members/loading/err; hapus: type-nama + askPin + RPC + clear active prefs bila WS aktif lalu pop ke switcher)**
- [ ] **Step 2: Hook gear di _OrgRow, commit**

```bash
git add lib/screens/workspace/workspace_detail_screen.dart lib/screens/workspace/org_switcher_screen.dart
git commit -m "feat: workspace detail (anggota + danger zone)"
```

### Task 6: Verifikasi + docs + APK

- [ ] **Step 1: `flutter analyze` + `flutter test` via CI (push branch/main -> pantau `gh run watch` sampai hijau)**
- [ ] **Step 2: Device boneka: buat WS -> undang akun kedua -> kick -> hapus; cek dompet ikut hilang; screenshot tiap layar yang disentuh**
- [ ] **Step 3: Delivery Gate antislop (lapor PASS per item, bukti klik)**
- [ ] **Step 4: Catat lokal `AGENTS.md` + `AUDIT.md`, push, unduh APK ke `/sdcard/Download/SSR-SPACE/`**

## Self-Review

- Spec coverage: S1 server -> Task 1+2; S2 client -> Task 3+5 (+PIN Task 4); S3 visual -> Task 5 (hero/ledger/chip, alasan tertulis di spec); S4 testing/rollout -> Task 6 + migration manual (tanpa SQL lain).
- Placeholder scan: tak ada TBD/TODO; semua langkah berisi kode/perintah persis.
- Type consistency: `list_org_members(p_org_id)` -> service `members(orgId)`; `kick_member(p_org_id, p_user_id)` -> `kickMember(orgId, userId)`; `delete_workspace(p_org_id)` -> `deleteWorkspace(orgId)`; `askPinDialog(context) -> Future<bool>`; kunci strings `wsm_*` dipakai Task 5.
