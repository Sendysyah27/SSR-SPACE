# Desain: Verifikasi NFC + Kartu→Dompet + Kelola Dompet (2026-09-28)

Keputusan user terkunci: A1 (gate 3-state), B (saldo-awal + tawar selisih),
C (rename/type tanpa PIN, hapus PIN + kosong saja, saldo-awal umum).

## 0. Fakta pengikat (hasil eksplorasi, jangan dilanggar)

- Saldo dompet = hitungan server dari transaksi (`wallet_balance`,
  `migration_09`). Angka tak bisa ditempel; harus masuk via transaksi.
- `transactions.wallet_id`/`to_wallet_id` FK ke `wallets(id)` TANPA cascade:
  hapus dompet bertransaksi DITOLAK database. Palang terakhir server.
- RLS `member wallets for all`: member biasa boleh update/delete dompet.
  Tanpa migration.
- `TransactionService().add({orgId, type, amount(double,>0), walletId,
  category, note, date,...})` mengembalikan id + mint kode TX otomatis.
- `WalletService().create` kini `Future<void>` — HARUS jadi `Future<String>`
  (return id) untuk taut + rollback. Satu pemanggil (`wallets_screen:156`,
  abaikan return → kompatibel).
- Kategori = free-text di transaksi; 10 default (`app_categories.dart`)
  TIDAK disentuh. `rb_record`/`rb_skip` dipakai ulang untuk tawaran.
- Hapus pakai `askPinDialog(context)` (`widgets/pin_dialog.dart`) —
  pola danger zone workspace.

## 1. Pecahan A — verifikasi/izin NFC (gate 3-state)

- Dep langsung baru: `flutter_nfc_kit: ^3.6.2` (kini transitif ^3.5.2;
  API `FlutterNfcKit.nfcAvailability → Future<NFCAvailability>`
  terverifikasi di docs 3.6.2; nilai: `not_supported`/`disabled`/
  `available`). Tanpa dep settings — tanpa deep-link (YAGNI).
- Di `NfcCardsScreen._load`, dalam try/catch (throw → `null` = tanpa gate,
  fail-soft ke error baca):
  - `not_supported` → tombol tempel disembunyi + SectionCard `nfc_no_hw`.
  - `disabled` → banner `nfc_off` + langkah `nfc_off_steps` (Pengaturan →
    Koneksi → NFC) + tombol `nfc_retry` (cek ulang).
  - `available`/`null` → normal.
- Test: mapping state→UI butuh widget test? Minimal: unit untuk helper
  murni bila ada; sisanya smoke device (3 state susah dipalsukan).

## 2. Pecahan B — kartu→dompet (finance flow)

### 2.1 Jadikan dompet (orkestrasi `linkCardAsWallet`, di `nfc_emoney.dart`)

Urutan (gagal di tengah = rollback, fail-clean):
1. `WalletService().create(orgId, '{BANK} •• {last4}', 'ewallet')` → id.
2. Simpan taut `NfcCard(uid, bank, last4, label, walletId: id)` via
   `saveNfcCards` (dedupe uid).
3. `TransactionService().add(orgId, type: 'in', amount: saldo.toDouble(),
   walletId: id, category: 'Saldo awal',
   note: 'Saldo awal {BANK} •• {last4} via NFC', date: hari tap)`.
4. `addNfcCheck` bila saldo valid.
- Bila (3) throw → `deleteWallet(id)` best-effort + buang taut + throw
  dengan pesan jujur. (1)/(2) gagal → throw langsung (tak ada sisa).
- Entri = setara manual (`sourcePackage` null, tanpa badge Otomatis):
  user yang menekan tombol.

### 2.2 Tap ulang kartu tertaut (tawar selisih)

- Ambil saldo buku dari `WalletService().balances(orgId)` (cari walletId).
  Dompet hilang → buang taut diam-diam + perlakukan belum tertaut
  (pola `markWalletGone`).
- Murni `nfcAdjustmentFor(book: double, card: int)` (TDD, di
  `nfc_emoney_logic.dart`): sama → null ("Sudah cocok", tanpa tawaran);
  card>book → `{type:'in', amount:card-book}` (top-up luar buku);
  card<book → `{type:'out', amount:book-card}` (belanja luar buku).
- Sheet: selisih + `rb_record` Catat / `rb_skip` Lewati. Catat →
  `add(type, amount, walletId, category: 'Penyesuaian',
  note: 'Penyesuaian NFC {BANK} •• {last4}')`.
- Kategori `Saldo awal` + `Penyesuaian` TIDAK masuk 10 default (laporan
  grouping normal; chips tak menyarankan — batas sadar tercatat).

## 3. Pecahan C — kelola dompet

### 3.1 Service (`WalletService` +)

- `Future<String> create(...)` return id
  (`.insert(...).select('id').single()`).
- `Future<void> rename(id, orgId, name)` — tolak kosong (client,
  pesan `w_err_name` reuse).
- `Future<void> changeType(id, orgId, type)` — tolak di luar
  {cash, ewallet, bank, savings, investment}.
- `Future<bool> hasTransactions(orgId, walletId)` — existence
  `.select('id').eq('org_id',...).or('wallet_id.eq.X,to_wallet_id.eq.X')
  .limit(1)` → isNotEmpty.
- `Future<void> deleteWallet(id, orgId)` — delete langsung; FK throw
  dipetakan ke pesan jujur (backstop, bukan alur utama).

### 3.2 UI

- `WalletDetailScreen`: aksi edit di AppBar → dialog (field nama +
  dropdown 5 tipe, pola `_NewWalletForm`) → simpan → reload.
  Tanpa PIN (reversibel).
- Danger zone bawah detail: tombol Hapus → `askPinDialog` → PIN salah/
  batal = diam → `hasTransactions` true = blokir `w_has_tx` (+ tawar
  ubah nama) → false = konfirmasi akhir → delete → pop + reload.
- `_NewWalletForm`: field nominal opsional `w_opening` → usai create
  (id) insert opening tx pola §2.1 (note tanpa suffix NFC);
  gagal → rollback hapus dompet + pesan.

### 3.3 Keamanan (lensa hardening, dikunci)

- Hapus = destruktif di workspace bersama: PIN + konfirmasi + guard
  kosong + FK backstop (4 lapis).
- Rename/type tanpa PIN: non-destruktif, reversibel, RLS sudah batasi
  member org sendiri.

## 4. Bersama

- Strings baru (ID+EN): `nfc_no_hw`, `nfc_off`, `nfc_off_steps`,
  `nfc_retry`, `nfc_make_wallet`, `nfc_matched`, `nfc_diff`,
  `w_rename_t`, `w_has_tx`, `w_deleted`, `w_opening`. Reuse:
  `rb_record`, `rb_skip`, `w_err_name`, `cancel`, `tx_delete`.
- Test: murni TDD (`nfcAdjustmentFor` arah/nol/negatif-guard,
  guard rename/type, masker reuse); service/RLS ikut CI;
  `flutter test` hijau sebelum APK.
- Urutan build: C-service → C-UI → A → B (B butuh create-return-id).
- Rilis: fitur perilaku baru → `2.4.12+46` (pubspec + AppInfo +
  changelog `## Yang baru di 2.4.12`); APK `*-arm64.apk` ke Download;
  catat AGENTS + AUDIT lokal.
- Risiko jujur: dep nfc_kit langsung = surface build baru (kecil;
  transitif sudah lolos); `hasTransactions` race (dibuat antara cek
  dan hapus → FK backstop + pesan); opening `in` menaikkan angka
  pemasukan/laporan (by design §2, jujur via kategori khusus).

## 5. Skill implementasi (permintaan user)

TDD (logika murni dulu) → antislop inti + UI/layoutmobile/copywriting/
human saat layar → security-and-hardening saat hapus (sudah dipakai
di §3.3) → verification-before-completion sebelum klaim hijau/APK.
