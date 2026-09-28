# Desain: Baca Saldo E-Money via NFC (2026-09-28)

## 1. Latar & vonis spike

Permintaan: tempel kartu e-money (fokus Flazz) → lihat saldo + opsional taut ke
dompet, atau sekadar histori cek. Pendekatan terpilih: paket
`prepaid_lib_flutter_null_safety` (satu-satunya yang klaim bisa baca 4 kartu
Indonesia: Mandiri, TapCash, Flazz, JakCard) + spike fisik throwaway.

Vonis spike: **LULUS untuk Mandiri di device user** (APK
`SSR-SPACE-2.4.10-44-spike-nfc-arm64.apk`, CI run `36414090384` hijau).
Bukti: `ok=true`, `saldo=100` konsisten dengan balance entri histori terakhir
(counter 15 → `100`), `bank=MANDIRI`, histori 11 entri terbaca. Flazz /
TapCash / JakCard belum terbukti di device (satu code path, klaim vendor).

Lima temuan spike yang mengikat desain (lihat §5).

## 2. Scope

MASUK:

- Baca UID + nomor + saldo + bank + histori kartu (bila disediakan kartu).
- Daftar kartu tertaut (UID → label + dompet opsional) + histori cek lokal.
- Kartu didukung penuh: Mandiri e-money (terbukti). Best-effort fail-soft:
  TapCash, Flazz, JakCard.

KELUAR (non-scope, eksplisit):

- Top-up / `updateBalance` (gerakkan uang beneran + butuh MID prod + email/HP).
  Tidak ada code path top-up di app.
- Insert transaksi otomatis dari selisih saldo (semantik salah: saldo kartu ≠
  mutasi; lihat §6).
- Migration Supabase. Semua state lokal di prefs (satu device).
- iOS (build hanya APK; kode wajib tetap compile, guard runtime Android).

## 3. Arsitektur & file yang berubah

Pertahankan dari spike (sudah terbukti, tinggal relabel komentar
`SPIKE THROWAWAY` → `NFC e-money`):

- `pubspec.yaml`: `prepaid_lib_flutter_null_safety: ^1.0.1` (jangan
  longgarkan tanpa cek ulang patch native).
- `.github/workflows/apk.yml`:
  - Patch `build.gradle` plugin: `jcenter()`→`mavenCentral()`, suntik
    `namespace` dari manifest plugin, lantai `compileSdk 35`, `jvmTarget 1.8`.
  - Inject `android.permission.NFC` + `uses-feature android.hardware.nfc`
    `required=false` (HP non-NFC tetap bisa install; cek runtime).
  - `minSdk` app 24→26 (tuntutan plugin; konsekuensi: Android 8.0+).

Hapus (janji spike):

- `lib/screens/lainnya/nfc_spike_screen.dart` + tile `Uji NFC (spike)` +
  seluruh wiring `onNfcSpike` di `other_screen.dart`.

Baru:

- `lib/services/nfc_emoney.dart` — wrapper tipis + murni parse (lihat §5).
  `initOnce()` (mode dev, MID dummy, return false = warning bukan gate),
  `readCard()` → `NfcCardRead`, `parseHistory()` murni.
- `lib/screens/lainnya/nfc_cards_screen.dart` — daftar kartu + tombol tempel.
- Bottom-sheet hasil: saldo, bank, histori kartu, aksi taut-ke-dompet /
  simpan-cek. Gaya ikut `DESIGN.md` + komponen ledger (tanpa bahasa visual
  baru; dial antislop During bila disentuh).
- Entry: satu `NavTile` "E-Money NFC" di seksi Data hub Profil (ganti tile
  spike, posisi sama).

## 4. Data (prefs lokal, tanpa migration)

- `nfc_cards`: JSON list, cap 20. Per kartu: `uid` (kunci stabil),
  `bank`, `last4`, `label` (edit user), `walletId` (opsional, nullable),
  `addedAt`. Nomor penuh TIDAK disimpan; tampil masker `6032 •••• 3976`.
- `nfc_history_checks`: JSON list, cap 50, entri `{uid, bank, saldo, at}`.
  Ini "histori cek" milik Flazz dkk (kartunya sendiri tak beri histori).
- Kartu tak dikenal (belum tertaut) tetap bisa dibaca sekali jalan tanpa
  disimpan (mode lihat saja).

## 5. Aturan parse (dari data spike asli, wajib jadi test)

- `bank`: uppercase apa adanya (`MANDIRI`); peta label: MANDIRI/BNI/BCA/DKI
  + fallback tampil mentah (jangan tolak kartu tak dikenal).
- `saldo`: `int.tryParse`; gagal = hasil invalid jujur, bukan 0.
- Histori kartu: sort by `counter` desc (kartu simpan urutan slot, acak).
- Tipe: `"1"` = kredit/top-up, `"2001"` = debit/bayar, selain itu =
  `unknown` (tampil apa adanya, tanpa tebak arah).
- `initUnikLib` return `false` tanpa exception = lanjut baca (terbukti bisa).
  Hard-fail hanya untuk exception / timeout / `errorNfc`.
- `getHistory=false` (Flazz dkk) = normal, pakai `nfc_history_checks` (§4).

## 6. Keputusan produk yang dikunci

- TIDAK ada sinkronisasi saldo otomatis ke dompet dan TIDAK ada transaksi
  auto dari selisih. Kartu tertaut menampilkan saldo kartu di samping dompet
  + tombol catat manual biasa (prefill nominal, tetap lewat konfirmasi user).
- Izin NFC diminta saat pertama buka layar (bukan saat install); HP tanpa
  NFC dapat pesan jujur, bukan crash.
- Copy ID mengikuti `strings.dart` (kunci baru `nfc_*` ID+EN).

## 7. Testing

- Unit (TDD, pola `dart --enable-asserts` lokal + `test/nfc_emoney_test.dart`
  di CI): parse saldo valid/gagal, sort counter desc, peta tipe 1/2001/
  unknown, masker nomor, cap list. Sampel = data spike asli (nomor disamarkan
  di test, UID asli boleh — bukan PAN pembayaran).
- CI hijau penuh (analyze 0 issue + test + APK) sebelum APK ke Download.
- Smoke device: Mandiri (terbukti) + Flazz bila ada kartu (best-effort).

## 8. Risiko jujur & batas sadar

- Vendor unverified, 39 downloads, publish 14 bln lalu; bila ditinggal,
  fallback = C (UID-link via `flutter_nfc_kit` langsung, tanpa saldo).
- 4 patch native di CI = utang: tiap bump Flutter/AGP bisa pecah lagi;
  assert keras di step memberi vonis cepat, bukan diam.
- Flazz/TapCash/JakCard belum terbukti device → copy UI janji "didukung"
  dilarang; yang dijanjikan: "coba baca, gagal = pesan jujur".
- MID prod + top-up selamanya di luar scope tanpa keputusan baru.

## 9. Rilis

- Bump patch (`+build` bila hanya rapihan, `+patch` bila perilaku baru) +
  entri `changelog_id.md` + `AppInfo.version` samakan (aturan §7 AGENTS.md).
- APK uji = varian `*-arm64.apk` ke `/sdcard/Download/SSR-SPACE/`.
- Catat lokal di AGENTS.md + AUDIT.md, commit docs gabung update berikut.
