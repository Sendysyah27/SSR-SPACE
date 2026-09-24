# Spec: Edit/Hapus Transaksi + Saldo per Dompet (Sprint A1+A2)

Tanggal: 2026-09-24  
Status: revised (antislop DURING) → menunggu review user  
Versi target: `2.3.4+16`  
Migration: `supabase/migration_09_wallet_balance.sql` (wajib user jalankan di Supabase Dashboard sebelum pakai APK)  
Filter UI: antislop core + `antislop-ui` + `antislop-layoutmobile` + `antislop-human` (mode DURING)

## Design Read (R-37)

> Aplikasi keuangan phone-first untuk pemakai Indonesia, bahasa visual buku kas yang tenang, dial **ENERGY 1 / RHYTHM 2 / MOTION 1** (dari `DESIGN.md`).

Arah ada (`DESIGN.md`): kertas `#FAFAF7`, tinta `#1C1B1A`, sekunder `#5F5E5B`, aksen zamrud `#0F766E`, danger bata `#B3261E` (selalu dengan label kata), motif garis ledger hairline, MOTION 1 (Material saja, no loop). Bukan draft.

## Konteks

Auto-track notifikasi bisa menyimpan transaksi dengan dompet salah (“Tersimpan (dompet belum cocok)”) atau kategori kosong. Saat ini `transactions_screen` hanya menambah (`ListTile.onTap == null`), tidak ada path update/delete di `TransactionService` (RLS `member tx` FOR ALL sudah mengizinkan). Dompet tidak punya saldo sama sekali (hanya total org di beranda).

Backlog: AUDIT.md Sprint A item A1 (edit transaksi) + A2 (saldo dompet).

## Goal (done when)

1. User dapat tap baris transaksi, ubah field (tipe, amount, wallet, kategori, tanggal, catatan, tujuan transfer), simpan tanpa duplikat kode TX.
2. User dapat hapus transaksi dengan konfirmasi.
3. Saldo per dompet tampil di layar Dompet dan sebagai subtitle dropdown wallet di form transaksi.
4. Transfer A ke B menghitung minus A dan plus B di view saldo.
5. User kedua tidak dapat membaca saldo org lain (RLS via `security_invoker`).
6. UI lolos Delivery Gate antislop (PASS semua blok) sebelum deliver.

Non-goals (backlog lain): 2-leg transfer (C1), rate limit (A3), audit log (A4), invite (A5), edit budget bulan lalu (C2).

## Keputusan desain (approved)

- **Approach 1, edit in-place**: mode edit di `transactions_screen` yang sama (bukan layar terpisah / widget ekstrak).
- **Saldo = SQL view** `wallet_balance` dengan `security_invoker = true` (bukan kalkulasi Dart client karena list UI limit 100/200).
- **Hapus = hard delete** via RLS langsung (bukan RPC). YAGNI sampai A4 audit log ada.
- Tampilan saldo: layar Dompet + subtitle dropdown form transaksi (bukan beranda).

## Desain

### 1. Database: `migration_09_wallet_balance.sql`

```sql
create or replace view public.wallet_balance
with (security_invoker = true) as
select
  w.org_id,
  w.id as wallet_id,
  coalesce(sum(case
    when t.type = 'in'       and t.wallet_id = w.id    then  t.amount
    when t.type = 'out'      and t.wallet_id = w.id    then -t.amount
    when t.type = 'transfer' and t.wallet_id = w.id    then -t.amount
    when t.type = 'transfer' and t.to_wallet_id = w.id then  t.amount
    else 0 end), 0)::numeric as balance
from public.wallets w
left join public.transactions t
  on t.org_id = w.org_id
 and (t.wallet_id = w.id or t.to_wallet_id = w.id)
group by w.org_id, w.id;

grant select on public.wallet_balance to authenticated;
```

Aturan:
- `security_invoker = true` agar policy viewer menjalankan RLS `wallets` + `transactions` milik caller, bukan bypass owner.
- Transfer tetap 1 row (semantic sekarang): `wallet_id` minus amount, `to_wallet_id` plus amount.
- Wallet tanpa transaksi: `0` (LEFT JOIN + COALESCE).
- Validasi form melarang transfer ke diri sendiri; jika lolos pun, CASE mengambil cabang pertama (minus). Accepted edge case.
- Grant hanya `select`; tidak ada insert/update di view.
- Nomor migration mengikuti pola `migration_NN_<slug>.sql`. **Jangan edit history migration lama.**

### 2. Model & service

**Baru: `lib/models/wallet_balance.dart`**

```dart
class WalletBalance {
  final String walletId;
  final double balance;
  const WalletBalance({required this.walletId, required this.balance});
  factory WalletBalance.fromMap(Map<String, dynamic> map); // wallet_id, balance numeric→double
}
```

**`lib/core/saas/transaction_service.dart`** (tambah):

- `Future<void> update({required String id, required String orgId, required String type, required double amount, String? walletId, String? toWalletId, String? category, String? note, String? date})`
  - `.update({…snake_case…}).eq('id', id).eq('org_id', orgId)`
  - Field di-update: `type, amount, wallet_id, to_wallet_id, category, note, date`.
  - **Tidak** diubah: `code`, `source_package`, `source_hash`, `created_by`, `created_at`, `org_id`.
- `Future<void> delete(String id, String orgId)`
  - `.delete().eq('id', id).eq('org_id', orgId)`

Validasi (amount > 0, wallet wajib, transfer tujuan ≠ sumber) di helper pure, dipanggil mode add dan edit.

**`lib/core/saas/wallet_service.dart`** (tambah):

- `Future<List<WalletBalance>> balances(String orgId)`
  - `from('wallet_balance').select().eq('org_id', orgId)`
  - Kegagalan dilempar; screen menangani state error (lihat §3).

### 3. UI (anti-slop DURING)

Semua copy UI: Bahasa Indonesia, **tanpa karakter em dash (R-02)**, tanpa emoji (R-04), tanpa buzzword (R-16), CTA spesifik (R-15). Uang selalu `rp()` + `SsrTheme.money` (tabular). Radius ikut design system: tombol 14, input 12, bukan pill seragam (R-11). Tanpa glow/gradient/kaca baru (R-01, R-10, R-13). MOTION 1: tanpa animasi kustom (R-19).

**Kontras terukur** (`antislop-human/contrast-check.py` di atas kertas `#FAFAF7`):

| Pairing | Ratio | AA normal |
|---------|-------|-----------|
| danger `#B3261E` on kertas | 6.25 | PASS |
| sekunder `#5F5E5B` on kertas | 6.20 | PASS |
| zamrud `#0F766E` on kertas | 5.23 | PASS |

**Alasan keputusan (R-31, satu baris):**

| Keputusan | Alasan |
|-----------|--------|
| Banner edit di atas form | Satu fokal per layar saat mode edit: konteks “sedang ubah apa” sebelum tombol simpan |
| Baris terpilih saat edit | Menandai state nyata (sedang diedit), bukan stripe dekoratif |
| Saldo di kanan baris Dompet | Angka uang jadi fokal skan cepat; motif ledger hairline dipertahankan |
| Subtitle dropdown `nama · Rp` | Bantu pilih dompet sebelum simpan, tanpa layar tambahan |
| Hapus = Outlined danger + dialog | Danger selalu berlabel kata (DESIGN.md); konfirmasi cegah hard delete salah |
| Placeholder saldo gagal: teks “Belum termuat” | Jangan tampilkan 0 palsu; em dash dilarang (R-02); jujur soal state (R-38) |
| Tanpa animasi masuk form | MOTION 1 dari DESIGN.md; scroll ke form cukup sebagai guidance |

#### `lib/screens/transactions_screen.dart`

State baru: `SaasTransaction? _editing`.

Alur edit:
1. `ListTile.onTap` → `_editing = t`; prefill form: `_type`, `_amount` (string), `_category`, `_note`, `_date`, `_walletId`, `_toWalletId`; scroll form ke viewport (`ScrollController.ensureVisible`) supaya field tidak tertutup keyboard (antislop-human).
2. Banner di atas form (saat `_editing != null`): teks “Mengubah `<code>`” + tombol teks **Batalkan edit** → clear `_editing` + reset form. Banner = fokal layar saat edit.
3. Baris list yang sedang diedit: `selected: true` (atau latar `SsrColors` seleksi state nyata, bukan warna hias).
4. Tombol utama: **Simpan transaksi** (add) / **Simpan perubahan** (edit). Min height 48px (tap target R-03).
5. Tombol **Hapus** (`OutlinedButton`, `SsrColors.danger`, label kata “Hapus”, hanya saat edit, min height 48px):
   - `showDialog` (barrierDismissible: true, tombol **Hapus** / **Batal**): “Hapus transaksi ini? Tidak bisa dibatalkan.”
   - Sukses → snackbar teks “Transaksi dihapus” (bukan warna saja, R-27/color-only) → clear edit → `_load()`.
6. Sukses edit → snackbar “Transaksi diperbarui” → clear edit → `_load()`.
7. Error → snackbar “Gagal menyimpan. Coba lagi.” / “Gagal menghapus. Coba lagi.”
8. Validasi gagal → pesan dari `validateTxInput` di bawah field terkait / snackbar, teks jelas sebab + langkah.

States (R-27):
- **Loading**: `LoadingView` existing saat `_load`.
- **Empty**: “Belum ada transaksi bulan ini. Catat pemasukan atau pengeluaran di form di atas.” (sebab + aksi, bukan “No data”).
- **Error**: `ErrorView` + retry existing.

Aturan:
- Setelah auto-track “dompet belum cocok”, tap baris, pilih wallet, simpan: daftar dan saldo ikut benar (A1 done-when).
- Kode TX tidak berubah saat edit (subtitle list tetap).
- `_load` memuat list bulan berjalan + wallets + balances untuk dropdown.
- Dropdown wallet: `DropdownMenuItem` = `nama` + (jika ada balance) ` · ` + `rp(balance)` kecil (`SsrTheme.money`, warna sekunder `#5F5E5B`, kontras 6.20 PASS). Balance miss → nama saja. Tanpa arrow dekoratif (R-08).

#### `lib/screens/wallets_screen.dart`

- `_load`: `WalletService.list` + `WalletService.balances`; join by `walletId`.
- Baris: kiri nama + type; kanan `rp(balance)` + `SsrTheme.money` (fokal skan). Hairline `Divider` tetap motif ledger.
- **State saldo:**
  - Loaded: nominal kanan.
  - Balances gagal (wallet list OK): nominal diganti teks sekunder **“Belum termuat”** (bukan angka 0, bukan em dash). List nama tetap jalan (graceful, C-4).
  - Loading: mengikuti `LoadingView` layar.
  - Empty: state no-org / empty existing, dengan teks aksi bila ada polanya.
  - Error total: `ErrorView` existing.
- Tap target baris: cukup untuk selectable list Material (≥48dp default ListTile).

#### Dropdown wallet di form (`transactions_screen`)

Lihat §3 point 4 keputusan. Fokus pilihan: nama dulu, saldo sekunder.

### 4. Validasi (helper pure, TDD)

**`lib/core/saas/tx_validation.dart`**:

```dart
String? validateTxInput({
  required double amount,
  required String? walletId,
  required String type,
  String? toWalletId,
});
```

Return `null` = OK, atau pesan error Indonesia (tanpa em dash):
- `amount <= 0` → “Nominal harus lebih dari 0”
- `walletId == null` → “Pilih dompet”
- `type == 'transfer' && toWalletId == walletId` → “Dompet tujuan sama dengan asal”
- `type == 'transfer' && toWalletId == null` → “Pilih dompet tujuan”

Dipakai mode add dan edit.

### 5. Testing

| File | Isi |
|------|-----|
| `test/wallet_balance_test.dart` | `WalletBalance.fromMap` (wallet_id, balance numeric int/double/String → double) |
| `test/tx_validation_test.dart` | kasus validasi di §4 |

- Formula saldo ada di SQL, tidak diuji unit lokal; verifikasi checklist manual device (§6).
- Tidak ada mock Supabase / integration test (konvensi repo: pure unit saja).
- Pattern: `test/dashboard_calc_test.dart`, `test/wallet_model_test.dart`.

### 6. Checklist verifikasi manual (device + SQL)

Tambahkan ke AUDIT.md §5:

- [ ] Jalankan `migration_09_wallet_balance.sql` di Supabase Dashboard
- [ ] Install APK `2.3.4+16` → Dompet: saldo tampil per baris; wallet baru = `Rp0`
- [ ] Tambah transaksi in 100.000 ke DANA → saldo DANA `Rp100.000`
- [ ] Tap baris → ubah wallet ke Bank → simpan → kode TX sama, saldo DANA/Bank berubah
- [ ] Transfer DANA→Bank 30.000 → DANA −30.000, Bank +30.000
- [ ] Hapus transaksi dengan konfirmasi → hilang dari list, saldo balik
- [ ] Form transaksi: dropdown menampilkan `nama · Rp…`
- [ ] Auto-track “dompet belum cocok” → tap → pilih dompet → simpan → baris “Otomatis” tetap, saldo benar
- [ ] User kedua: query `select * from wallet_balance` → hanya row org sendiri (atau kosong)
- [ ] Balances gagal load: Dompet tetap tampil nama, nominal “Belum termuat”, bukan 0
- [ ] Empty list Transaksi: teks ajakan catat, bukan layar kosong tanpa keterangan
- [ ] Tombol Hapus / Simpan / Batalkan edit: mudah ditekan satu tangan, tanpa overflow horizontal di layar kecil
- [ ] Tidak ada `—` (em dash) di copy UI hasil build

### 7. Delivery Gate antislop (wajib sebelum deliver)

Sebelum serah APK / commit final UI, jalankan Delivery Gate antislop dan lampirkan laporan PASS/FAIL di jawaban akhir:

- **Block 1 Hard Gate**: R-02 (no em dash di copy), R-03 (no overflow, tap ≥44px), R-25 (kontras tabel di atas), R-26 (semua tombol nyata), R-27 (empty/loading/error), R-32 (dialog bisa dismiss, focus order form), R-35 (click-through via CI test + checklist device; bila flutter tidak jalan lokal, verifikasi kode + checklist), R-37 (Design Read di atas), R-38 (tidak ada angka/stat fiktif).
- **Block 2 Purpose-Gate**: alasan R-31 di tabel keputusan; tidak ada gradient/glow/icon sparkle baru.
- **Block 3 Liveliness**: dials ENERGY 1 / RHYTHM 2 / MOTION 1 konsisten; satu fokal per layar (banner edit / saldo kanan); whitespace struktural; aksen zamrud tidak disebar ke semua elemen; motif hairline ledger dipertahankan; Design Read dideklarasikan.
- **Block 4 Craftsmanship**: C-1..C-5; R-05 layout mengikuti konten layar app (bukan template landing); R-11 radius design system; R-15 CTA spesifik; R-16 tanpa buzzword; R-20 identitas buku kas; R-29 palette ≤ 2-3 core + 1 accent (sudah DESIGN.md); R-30 bukan klone produk lain.

Gate FAIL → perbaiki dulu, ulangi, jangan deliver.

### 8. File diubah / dibuat

| Aksi | Path |
|------|------|
| baru | `supabase/migration_09_wallet_balance.sql` |
| baru | `lib/models/wallet_balance.dart` |
| baru | `lib/core/saas/tx_validation.dart` |
| baru | `test/wallet_balance_test.dart` |
| baru | `test/tx_validation_test.dart` |
| edit | `lib/core/saas/transaction_service.dart` |
| edit | `lib/core/saas/wallet_service.dart` |
| edit | `lib/screens/transactions_screen.dart` |
| edit | `lib/screens/wallets_screen.dart` |
| edit | `AUDIT.md` (tandai A1/A2 selesai + checklist) |
| edit | `pubspec.yaml` → `2.3.4+16` |

### 9. Delivery workflow (ikuti AGENTS.md)

1. TDD: test dulu → implement → `flutter test` / analyze di CI (flutter tidak ada di Termux).
2. `git add` → commit `feat: edit/delete tx + wallet balance view` → push main. (User sudah gas eksekusi; commit per langkah logis.)
3. Pantau `gh run watch … --exit-status`.
4. Hijau → `gh run download … -n ssr-space-apk` → copy ke `/sdcard/Download/SSR-SPACE/`.
5. Sebut ke user: **wajib jalankan migration_09 di Supabase** sebelum buka fitur saldo.
6. Lampirkan **Delivery Gate PASS report** (§7) di jawaban akhir.

### 10. Risks / open issues

- View `security_invoker` butuh Postgres ≥ 15 (Supabase hosted OK). Jika gagal: RPC read-only membership-checked, eskalasi ke user.
- List transaksi limit 100; saldo tetap akurat karena view aggregate penuh di server.
- `balance` `numeric` dari Postgrest bisa `int`/`double`/`String`; `fromMap` wajib tangani `num` dan `String`.
- Belum ada soft-delete / audit; permanen. A4 menyusul sub-projek terpisah.
- R-32 keyboard penuh di Flutter terbatas pada focus traversal bawaan; dialog wajib dismissible.

## Referensi

- AGENTS.md §3.3 workflow, §4.3/4.4 dompet/transaksi, §7 aturan RLS
- AUDIT.md §4 Sprint A A1/A2, §5 checklist, §6 test
- DESIGN.md dials + palette + motif + MOTION 1
- antislop: core Delivery Gate, antislop-ui checklist, antislop-layoutmobile (R-03), antislop-human (kontras, keyboard)
- Kode: `transaction_service.dart` (add/mint), `transactions_screen.dart` `_save` L64-91, `wallets_screen.dart`, `schema.sql` policy `member tx`, `migration_05`/`07` pola RPC
