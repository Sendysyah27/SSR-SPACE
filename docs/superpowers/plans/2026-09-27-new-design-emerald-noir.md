# New Design Emerald Noir Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rombak visual seluruh aplikasi ke Emerald Noir dark-first tanpa mengubah satu pun alur, logika, atau data.

**Architecture:** Fondasi dulu (`SsrColors` noir + `SsrTheme.noir()` + wiring `main.dart` + `DESIGN.md`), lalu layar per layar memakai token fondasi. Tiap task berakhir di commit yang dikompilasi-bersih secara diff-review; `flutter analyze` dan `flutter test` penuh hanya di CI (flutter tidak ada di Termux).

**Tech Stack:** Flutter stable (Material 3), Phosphor Duotone (sudah dibundel), fl_chart yang sudah ada, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-27-new-design-emerald-noir-design.md`

## Global Constraints

- Visual-only: tanpa migration Supabase, tanpa tabel atau RLS baru.
- Tanpa dependensi pubspec baru, tanpa aset baru (font Phosphor Duotone dan Fraunces sudah dibundel).
- Jangan sentuh `lib/services/notif_track_service.dart` gate `_onEvent`, RLS, TX-code, atau alur data apa pun.
- Copy pengguna Indonesia identik; bila satu kata harus berubah, catat di laporan task dan minta ruling controller.
- Nominal lewat `amt()`, tanggal lewat helper yang ada (`dayLabel`, `monthLabel`, `txWhenLabel`).
- Setiap pasangan teks utama wajib lolos WCAG AA (normal 4.5:1, besar 3:1); bukti berupa tabel ukur di laporan tiap task, bukan klaim.
- `build()` layar tetap di bawah 50 baris; reuse widget yang ada; tanpa bahasa visual baru di luar spec.
- Tanpa em dash di copy mana pun.
- `flutter analyze` wajib 0 issue (info pun fatal di repo ini).
- Version Skema A: satu bump `2.4.0+23` ke `2.4.1+24` (`pubspec.yaml` + `lib/utils/app_info.dart` identik) di task terakhir, catat `AUDIT.md` §7 dan `AGENTS.md` lokal.
- Push ke main hanya oleh controller setelah semua review CLEAN dan user bilang ya.

## Ruling scope

Spec mencakup seluruh aplikasi (banyak subsistem). Tetap SATU plan dengan
task sekuensial (bukan multi-plan) karena user memutuskan Sekaligus satu
push: fondasi dulu, layar menyusul memakai token fondasi. Tanpa task
paralel (semua menyentuh token dan layar yang bertetangga).

---

## File map

- Fondasi: `lib/theme/app_theme.dart` (tambah `SsrTheme.noir()`, perluas `SsrColors`), `lib/main.dart` (pakai `noir()`), `DESIGN.md` (tulis ulang palet dan dial).
- Ikon: `lib/theme/app_icons.dart` + `lib/widgets/` pemakai ikon + layar intro (ganti Material ke Duotone yang relevan).
- Auth: `lib/screens/auth/` (splash, intro_consent, auth, lock, onboarding).
- Beranda: `lib/screens/beranda/beranda_screen.dart`.
- Transaksi: `lib/screens/transaksi/transactions_screen.dart` + `lib/widgets/day_header.dart` + `lib/widgets/tx_row.dart`.
- Dompet: `lib/screens/dompet/wallets_screen.dart` + `wallet_detail_screen.dart` + `lib/widgets/wallet_row.dart` + `lib/widgets/wallet_art.dart`.
- Budget: `lib/screens/budget/budgets_screen.dart`.
- Laporan: `lib/screens/laporan/reports_screen.dart`.
- Lainnya: `lib/screens/lainnya/` (other, settings, settings_search, notif_settings, billing, import_preview, update_log, categories, recurring_bills) + `lib/widgets/nav_tile.dart` + `labeled_section_card.dart`.
- Workspace: `lib/screens/workspace/` (org_switcher, invite, workspace_detail).
- Sheet: `lib/widgets/tx_input_sheet.dart` + `tx_numpad.dart` + `correct_sheet.dart` + `correct_overlay.dart` + `skeletons.dart` + `success_lottie.dart` + `state_views.dart` + `status_chip.dart` + `section_card.dart` + `primary_button.dart` + `pin_field.dart` + `mask_toggle.dart` + `month_picker.dart`.

---

### Task 1: Fondasi token noir plus wiring plus DESIGN.md

**Files:**
- Modify: `lib/theme/app_theme.dart`, `lib/main.dart`, `DESIGN.md`

**Interfaces:**
- Consumes: tidak ada (fondasi pertama).
- Produces: `SsrColors.noirBg=#0C1210`, `noirSurface=#141C18`, `noirRaised=#1B2521`, `noirLine=#2A3530`, `noirInk=#F2EFE6`, `noirSecondary=#A8A39A`, `mint=#2DD4BF`, `rose=#F87171`, `gold=#C6A15B` (semua `static const Color` di `SsrColors`); `SsrTheme.noir()` (ThemeData dark: scaffold noirBg, surface noirSurface, primary mint, onPrimary noirBg-ink gelap `#0C1210`, error rose, outline noirLine, skema input/snackbar/switch/divider mengikuti); `main.dart` memakai `theme: SsrTheme.noir()`.

- [ ] **Step 1: Tulis token dan theme**

Tambahkan 9 konstanta warna ke `SsrColors` (nama dan hex persis di atas) lalu tulis `SsrTheme.noir()` meniru struktur `SsrTheme.light()` yang ada: appBar noirBg, teks primer noirInk, sekunder noirSecondary, tombol primer mint dengan teks `#0C1210`, input fill noirSurface + border noirLine + focus mint 1.6, divider noirLine, snackbar noirRaised dengan teks noirInk, switch selected mint. Radius, spasi, motion tidak berubah.

- [ ] **Step 2: Wiring main dan DESIGN.md**

`main.dart`: ganti `theme: SsrTheme.light()` menjadi `theme: SsrTheme.noir()`. `DESIGN.md`: ganti §Palette ke 9 nilai di atas, §Dials ke ENERGY 2 / RHYTHM 2 / MOTION 1, §Motif tetap ledger, tambah §Kartu gelap menjadi §Emerald Noir (single dark theme, tanpa toggle, R-21: gelap adalah identitas).

- [ ] **Step 3: Tabel kontras**

Hitung rasio WCAG untuk pasangan: noirInk di noirBg, noirInk di noirSurface, noirSecondary di noirBg, mint di noirBg, `#0C1210` di mint, rose di noirBg, gold di noirBg, putih di mint. Cara: skrip `dart` kecil rumus luminans relatif (sRGB linearize) di `/tmp`, catat 8 angka di laporan. Semua wajib >= 4.5 (teks normal) kecuali teks besar >= 3.0; bila gagal, ganti nilai dan ulangi (catat perubahan sebagai ruling di laporan).

- [ ] **Step 4: Verifikasi diff dan commit**

Baca diff: hanya 3 file, tanpa sentuh logika, tanpa em dash, tanpa dep baru.
```bash
git add lib/theme/app_theme.dart lib/main.dart DESIGN.md
git commit -m "design: fondasi token emerald noir"
```

---

### Task 2: Migrasi ikon ke Phosphor Duotone

**Files:**
- Modify: `lib/theme/app_icons.dart`, pemakai `Icons.` di `lib/screens/` dan `lib/widgets/` (ganti yang relevan satu per satu), `pubspec.yaml` TIDAK diubah (TTF sudah dibundel).

**Interfaces:**
- Consumes: token Task 1 (tidak ada nilai baru).
- Produces: nol `Icons.` tersisa di layar aplikasi (intro sudah Duotone/Fill, biarkan); tiap ganti memakai glif yang relevan dengan kontennya.

- [ ] **Step 1: Inventarisasi**

Grep `Icons\.` di `lib/` dan catat tiap situs (file:baris, makna ikon). Hanya ikon aplikasi; abaikan yang di test atau komentar.

- [ ] **Step 2: Ganti satu per satu**

Tiap situs diganti ke `AppIcons`/`DuoIcon` yang relevan (contoh: dompet ke ikon dompet, bukan ikon generik). Pola const ikut pelajaran CI: field `static const`, `const` hanya di call-site full-const.

- [ ] **Step 3: Verifikasi dan commit**

Grep ulang `Icons\.` di `lib/` harus nol. Baca diff per file.
```bash
git add lib/theme/app_icons.dart lib/screens lib/widgets
git commit -m "design: ikon phosphor duotone penuh"
```

---

### Task 3: Auth flow (splash, lock, intro, auth, onboarding)

**Files:**
- Modify: `lib/screens/auth/splash_screen.dart`, `lock_screen.dart` (nama aktual dicek dulu), `intro_consent_screen.dart`, `auth_screen.dart`, `onboarding_screen.dart`, `lib/widgets/pin_field.dart`.

**Interfaces:**
- Consumes: token noir Task 1, ikon Task 2.
- Produces: momen brand (Anton + hairline emas `#C6A15B` 1px); lock rapat tanpa ruang kosong (6 kotak PIN, tombol Buka penuh); copy identik.

- [ ] **Step 1: Terapkan per layar**

Splash: wordmark Anton noirInk + hairline emas + tagline sekunder. Lock: komposisi vertikal rapat (logo kecil, judul, 6 kotak, tombol), tanpa area kosong besar. Intro: 4 halaman ikut surface noir, dots mint, checkbox dan tombol Setuju seirama. Auth dan onboarding: input dan tombol ikut theme (tanpa override warna lokal).

- [ ] **Step 2: Verifikasi dan commit**

Baca diff: tanpa ubah controller, session, PIN hash, atau navigasi. Tiap `build()` < 50 (ekstraksi bila perlu).
```bash
git add lib/screens/auth lib/widgets/pin_field.dart
git commit -m "design: auth flow emerald noir"
```

---

### Task 4: Beranda

**Files:**
- Modify: `lib/screens/beranda/beranda_screen.dart` (+ widget kecil sefile bila perlu).

**Interfaces:**
- Consumes: token Task 1.
- Produces: hero surplus (bg surface terangkat, garis aksen emas 2px atas, angka Fraunces noirInk, Masuk mint dan Keluar rose berdampingan dengan label kata); calm streak dot (isi mint, kosong noirLine); tombol Catat primer mint; Budget dan Laporan outlined; grup hari ikut Task 6.

- [ ] **Step 1: Terapkan**

Hero, streak, tombol, daftar terbaru. Mask toggle tetap. Copy dan rumus angka tidak berubah.

- [ ] **Step 2: Verifikasi dan commit**

```bash
git add lib/screens/beranda
git commit -m "design: beranda emerald noir"
```

---

### Task 5: Transaksi

**Files:**
- Modify: `lib/screens/transaksi/transactions_screen.dart`, `lib/widgets/day_header.dart`, `lib/widgets/tx_row.dart`.

**Interfaces:**
- Consumes: token Task 1.
- Produces: header hari tegas (tanggal titleSmall noirInk + hitung bodySmall sekunder); TxRow di surface noir (ikon kategori Duotone, nominal tabular, chip ikut gaya baru); banner tanpa-dompet roseSoft di atas noir (teks kontras AA, bukan pink terang); FAB dengan padding akhir agar tak menutup baris.

- [ ] **Step 1: Terapkan**

Header, baris, banner, padding. Filter dan month picker ikut theme.

- [ ] **Step 2: Verifikasi dan commit**

```bash
git add lib/screens/transaksi lib/widgets/day_header.dart lib/widgets/tx_row.dart
git commit -m "design: transaksi emerald noir"
```

---

### Task 6: Dompet

**Files:**
- Modify: `lib/screens/dompet/wallets_screen.dart`, `wallet_detail_screen.dart`, `lib/widgets/wallet_row.dart`, `lib/widgets/wallet_art.dart`.

**Interfaces:**
- Consumes: token Task 1.
- Produces: strip komposisi (donut mint, saving emas, investments sekunder; sembunyi bila < 2 bucket, logika tak berubah); baris dompet (nama noirInk, saldo tabular, WalletArt); form tambah ikut input theme; opsi Tabungan dan Investasi berlabel benar.

- [ ] **Step 1: Terapkan**

Strip, daftar, detail, form. Saldo gagal muat tetap pesan Belum termuat.

- [ ] **Step 2: Verifikasi dan commit**

```bash
git add lib/screens/dompet lib/widgets/wallet_row.dart lib/widgets/wallet_art.dart
git commit -m "design: dompet emerald noir"
```

---

### Task 7: Budget

**Files:**
- Modify: `lib/screens/budget/budgets_screen.dart`.

**Interfaces:**
- Consumes: token Task 1.
- Produces: kartu gauge (cincin mint, bata bila lewat batas); kartu Tabungan emas (ilustrasi savings yang sudah ada, pace tetap); form Batas baru seirama input global; hapus via PIN tetap.

- [ ] **Step 1: Terapkan**

  Gauge math (`budgetProgress`, pace `savingPace`), CRUD (`setBudget`,
  `deleteBudget`), PIN hapus (`_confirmPin`, `_submitPin`), dan navigasi:
  nol sentuh. Copy `tr()` identik; `amt()` tetap; CategoryChips dan
  StatusChip apa adanya (milik T10, jangan restyle).
  - `_OverAllocBanner`: `dangerSoft` jadi tint rose 0.14 + border rose 0.45
    (pola banner T5), teks noirInk eksplisit.
  - `_BudgetCard`: SectionCard noirSurface/noirLine, judul noirInk eksplisit;
    StatusChip dibiarkan (T10).
  - `_BudgetGauge` + `_gaugeData`: `accent` jadi mint, `danger` jadi rose,
    track `accentSoft` terang jadi noirLine; angka tengah tabular ikut warna
    cincin (mint/rose/gold).
  - `_SavingCard`: SectionCard tint gold 0.14 + border gold 0.45 (pola
    `_SavingStrip` T6); gauge `saving`/`savingSoft` lama jadi gold/noirLine;
    ilustrasi `savings.svg` dan baris pace tetap; judul noirInk, pace
    noirSecondary eksplisit.
  - `_SavingChip`: bg tint gold 0.18, teks gold (bukan `saving` lama yang
    gagal kontras di noir).
  - `_BudgetForm`: SectionCard noirSurface/noirLine, judul noirInk, error
    `danger` jadi `rose`; input ikut `SsrTheme.noir()` otomatis.
  - Dialog edit/hapus: tombol hapus `danger` jadi `rose` (kontras AA);
    controller PIN dan copy dialog tetap.

- [ ] **Step 2: Verifikasi dan commit**

```bash
git add lib/screens/budget
git commit -m "design: budget emerald noir"
```

---

### Task 8: Laporan

**Files:**
- Modify: `lib/screens/laporan/reports_screen.dart`.

**Interfaces:**
- Consumes: token Task 1.
- Produces: donut tiga iris (mint, rose, emas) dengan persen tengah; legenda anti-potong (wrap dua baris: label + nominal `amt()` penuh); kartu Masuk dan Keluar; selisih Fraunces; tombol Unduh CSV dan PDF berpasangan; filter dompet segaya input lain (tetap `initialValue:`); rekap kategori dan hints transfer ikut surface.

- [ ] **Step 1: Terapkan**

  Logika (`filterByWallet` + fail-open stale, `top8PlusOthers`, `sanitizeSectionOrder`,
  `setReportSectionOrder`, `detectTransferPairs`, `groupDayBuckets`, `savingOutOf`,
  `topOf`, export CSV/PDF + `_guardPdf`, `initialValue:` dropdown) nol sentuh; `amt()`
  penuh tanpa truncate; copy `tr()` identik; tanpa em dash.
  - `_MonthFlowChart` + `_DonutDial`: SectionCard noirSurface/noirLine; iris
    `accent` jadi mint, `danger` jadi rose, `saving` jadi gold; placeholder
    `surfaceMuted` terang jadi noirLine; persen tengah noirInk eksplisit.
  - `_FlowLegend` (bug headline `Rp3.698....`): baris `Row` + `ellipsis` dibuang,
    jadi titik warna + `Column` dua baris (label bodySmall noirSecondary, nominal
    `amt()` penuh bodyMedium w600 tabular warna arus); tanpa `overflow`.
  - `_FlowFilter`: `SegmentedButton.styleFrom` eksplisit (bg noirSurface, fg
    noirSecondary, selected bg tint mint 0.16 + fg mint, side noirLine).
  - `_MonthlySummary`: `_statCard` SectionCard noir, label noirSecondary, Masuk
    mint / Keluar rose (`SsrTheme.money` Jakarta tabular dipertahankan, kolom
    angka tetap Jakarta); selisih diekstrak `_NetCard` (Fraunces
    `SsrType.moneyLarge`, mint bila surplus, rose bila defisit); tombol Unduh
    CSV/PDF berpasangan apa adanya (ikut `outlinedButtonTheme` noir).
  - `_TransferHints`, `_CategoryRecap` (+ `_RecapRow`, `_RecapOthers` baru),
    `_TxListCard`: SectionCard noirSurface/noirLine, judul noirInk, subteks
    noirSecondary; cabang ciut/kembang Others identik (termasuk ciut-tanpa-sisa
    dan kembang-tanpa-sisa); `theme.colorScheme.primary` (mint) dibiarkan.
  - `_WalletFilterDropdown` + `MonthPicker` + tombol Susun: nol ubah (ikut
    `inputDecorationTheme`/`textButtonTheme` noir otomatis).
  - `build()` utama 121 jadi 35 via `_MonthFigures` + `_totalsFor` (pindah
    hitungan identik) + `_ReportHeader` + `_ReportSections` (relokasi builder
    ListenableBuilder + closure reorder identik); `_DonutDial` via `_sections()`
    + `_DonutCenter`; `_CategoryRecapState` via `_RecapRow`/`_RecapOthers`
    (sudah 65+ sebelum T8, pola ekstraksi T7); `_MonthlySummary` via `_NetCard`.

- [ ] **Step 2: Verifikasi dan commit**

```bash
git add lib/screens/laporan
git commit -m "design: laporan emerald noir"
```

---

### Task 9: Lainnya, settings, dan workspace

**Files:**
- Modify: `lib/screens/lainnya/` (other, settings, settings_search, notif_settings, billing, import_preview, update_log, categories, recurring_bills), `lib/screens/workspace/` (org_switcher, invite, workspace_detail), `lib/widgets/nav_tile.dart`, `labeled_section_card.dart`.

**Interfaces:**
- Consumes: token Task 1.
- Produces: kartu seksi noir dengan ikon Duotone; subtitle jujur P2 yang berulang disapu menjadi SATU baris status di kepala tiap seksi (copy jujur dipertahankan, noise hilang); kontrol (dropdown, switch, slider) ikut theme; workspace picker dan invite seirama; nol dead tap tetap.

- [ ] **Step 1: Terapkan hub dan settings**

- [ ] **Step 2: Terapkan workspace**

- [ ] **Step 3: Verifikasi dan commit**

```bash
git add lib/screens/lainnya lib/screens/workspace lib/widgets/nav_tile.dart lib/widgets/labeled_section_card.dart
git commit -m "design: lainnya settings workspace emerald noir"
```

---

### Task 10: Sheet, numpad, dan state umum

**Files:**
- Modify: `lib/widgets/tx_input_sheet.dart`, `tx_numpad.dart`, `correct_sheet.dart`, `correct_overlay.dart`, `skeletons.dart`, `success_lottie.dart`, `state_views.dart`, `status_chip.dart`, `section_card.dart`, `primary_button.dart`, `mask_toggle.dart`, `month_picker.dart`, `lib/screens/shell/main_shell.dart` (nav saja).

**Interfaces:**
- Consumes: token Task 1.
- Produces: numpad premium (tombol surface terangkat, kontras AA, feedback tekan); chip kategori seirama; segmented Masuk, Keluar, Transfer SATU gaya (mint isi untuk pilihan, bukan dua warna); bottom nav noir (aktif mint, nonaktif sekunder); skeleton meniru bentuk konten; snackbar dan status konsisten.

- [ ] **Step 1: Terapkan sheet dan numpad**

Logika numpad, validasi, dan hook most-used tidak berubah.

- [ ] **Step 2: Terapkan nav dan state umum**

- [ ] **Step 3: Verifikasi dan commit**

```bash
git add lib/widgets lib/screens/shell
git commit -m "design: sheet nav state emerald noir"
```

---

### Task 11: Version bump, docs, dan kunci akhir

**Files:**
- Modify: `pubspec.yaml`, `lib/utils/app_info.dart`, `AUDIT.md`, `AGENTS.md`

**Interfaces:**
- Consumes: semua task di atas selesai dan CLEAN.
- Produces: `pubspec.yaml` `version: 2.4.1+24` dan `AppInfo.version = '2.4.1+24'` identik; baris changelog `AUDIT.md` §7; baris status `AGENTS.md`.

- [ ] **Step 1: Bump dan docs**

Fitur perilaku tidak berubah (visual-only) tetapi scope full-app: naik minor `2.4.0+23` ke `2.4.1+24`.

- [ ] **Step 2: Commit (JANGAN push)**

```bash
git add pubspec.yaml lib/utils/app_info.dart AUDIT.md AGENTS.md
git commit -m "chore: new design emerald noir + bump 2.4.1+24"
```

Push hanya oleh controller setelah final review dan izin user.

---

## Self-review (controller, sebelum eksekusi)

- Cakupan spec: §2 palet ke Task 1; §3 tipo/ikon ke Task 1 dan 2; §4 motif ke Task 1, 4, 5; §5 tiap layar ke Task 3 sampai 10; §6 batasan ke Global Constraints tiap task; §8 rollout ke urutan task. Penuh.
- Placeholder: tidak ada TBD/TODO; tiap langkah ada aksi dan file konkret.
- Konsistensi tipe: nama token Task 1 dipakai verbatim di Task 4 sampai 10; `initialValue:` disebut eksplisit di Task 8 (pelajaran Paket R).
