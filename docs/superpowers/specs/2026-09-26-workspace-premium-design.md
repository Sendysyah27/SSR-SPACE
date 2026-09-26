# Design: Workspace Premium (anggota + hapus) — 2026-09-26

Keputusan user: visual premium + kelola anggota. Antislop mode DURING.
Arah visual: DESIGN.md (Fintech Ledger, dial ENERGY 2 / RHYTHM 2 / MOTION 2).

## 1. Server (`supabase/migration_14_workspace_admin.sql`, baru)

Dua RPC SECURITY DEFINER (pendekatan B; anti-rekursi: tanpa subquery
`org_members` di policy, cek via `is_org_admin`):

- `kick_member(p_org_id uuid, p_user_id uuid)`:
  tolak bila pemanggil bukan owner/admin; tolak bila target owner terakhir;
  tolak bila target diri sendiri (keluar diri = tombol terpisah, belum scope).
- `delete_workspace(p_org_id uuid)`:
  hanya owner/creator; hapus 1 baris `organizations` (cascade ke semua
  tabel org: members, wallets, transactions, budgets, invites, audit —
  cascade terverifikasi ada di schema + migration 03/04/05/10/11).

Test RLS (`supabase/test/rls_test.sql`, T12-T15): kick sembarang ditolak,
kick member lolos, owner-terakhir ditolak, hapus non-owner ditolak,
hapus owner lolos + cascade terverifikasi.

Identitas anggota: ID + peran saja (tanpa kolom email baru; privasi).

## 2. Client

- `lib/services/workspace_service.dart` (baru): `members(orgId)`,
  `kickMember(orgId, userId)` -> RPC, `deleteWorkspace(orgId)` -> RPC.
- `WorkspaceDetailScreen` (baru, dari ketuk baris workspace):
  hero gelap (nama + peran + jumlah anggota real); daftar anggota
  (penanda Kamu, ID terpotong, chip peran, tombol Keluarkan utk admin);
  zona danger (Hapus workspace: ketik-nama-konfirmasi + `verifyPin`,
  pola sama dengan edit budget); undang via invite yang sudah ada.
- Error jujur bila migration_14 belum dijalankan user.

## 3. Visual (Design Read + alasan R-31)

Read: layar pengaturan workspace untuk pemakai Indonesia, bahasa visual
Fintech Ledger, dial ENERGY 2 / RHYTHM 2 / MOTION 2.

- Hero gelap per workspace: identitas butuh panggung, bahasa sama dengan
  kartu surplus Beranda.
- Baris anggota hairline ledger: motif produk, bukan dekorasi.
- Chip peran = StatusChip lama (tanpa badge baru).
- Tanpa ilustrasi/angka baru selain jumlah anggota real (R-17).

## 4. Testing + rollout

- CI: analyze + test + RLS suite hijau.
- Device: WS boneka -> undang -> kick -> hapus (cek cascade).
- Delivery Gate antislop sebelum APK (klik semua, empty/loading/error,
  kontras AA, tanpa em dash).
- Rollout: user jalankan `migration_14` manual di SQL Editor (tanpa SQL lain).

## 5. Bukan scope

Ubah peran, keluar-sendiri, foto/cover workspace, statistik tambahan.
(PIN deep-link pasca-restart: flag in-memory, buka Settings ulang bila rute hilang.)
