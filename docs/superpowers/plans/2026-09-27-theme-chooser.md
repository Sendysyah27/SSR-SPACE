# Pilihan Tema Otomatis + Noir Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menambah pilihan tema `Otomatis` (default, Ledger light/dark ikut sistem) dan `Noir` (gelap selalu), dengan satu langkah pilih tema saat setup user baru, plus konversi 127 pemakaian `AppColors.` mati jadi sadar-tema via `colorScheme`.

**Architecture:** Prefs lokal `app_theme_choice` + `ValueNotifier<String> themeChoice` di `app_settings.dart` (pola setter existing). `SsrTheme.noir()` + 6 token noir di-restore dari commit `0bdeb7b` (versi terakhir sebelum sapu ledger, parent dari `569c6ec`), radius disesuaikan ke `SsrRadius` sekarang. `main.dart` membungkus MaterialApp dengan `ValueListenableBuilder(themeChoice)`: `noir` → `theme`+`darkTheme` keduanya `SsrTheme.noir()` (themeMode tetap system, tanpa baca brightness untuk paksa mode). Konversi `AppColors.` mati mengikuti aturan mapping spec §3, dinilai per situs.

**Tech Stack:** Flutter stable, shared_preferences, colorScheme M3. `flutter analyze` 0 issue (info pun fatal). `flutter` tak ada di Termux, verifikasi via CI.

**Spec:** `docs/superpowers/specs/2026-09-27-theme-chooser-design.md` (otoritas pengerjaan).

## Global Constraints

- Versi: `2.4.2+25` → `2.4.3+26` (pubspec.yaml + `AppInfo.version` identik, Skema A).
- `flutter analyze` wajib 0 issue; tanpa `const` buta (`Border.all`/`BorderRadius.circular` non-const; cek tiap situs).
- `initialValue:` untuk `DropdownButtonFormField` (bukan `value:`).
- Nominal lewat `amt()`, copy Indonesia, tanpa em dash (`—`).
- Tanpa migration, tanpa dep baru, tanpa `google_fonts`/`phosphor_flutter`.
- Mapping konversi (spec §3, dinilai per situs, bukan ganti buta):
  - `AppColors.emerald` / `emeraldBright` → `scheme.primary`
  - `AppColors.ink` / `inkDark` → `scheme.onSurface`
  - `AppColors.inkSoft` / `inkSoftDark` → `scheme.onSurfaceVariant`
  - `AppColors.line` / `lineDark` → `scheme.outline`
  - `AppColors.cream` → hero text light: `scheme.onPrimary`; bg kartu: `scheme.surface`
  - `AppColors.bgDark` → `scheme.surfaceContainerLowest`; `surfaceDark` → `scheme.surface`
  - `AppColors.rust` → `scheme.error`
  - `AppColors.emeraldDeep` → TETAP (momen brand hero, dua mode)
  - `AppColors.gold` / `goldSoft` / `chipSurplusText` / `chipAutoBg` / `chipWarnBg` → TETAP (lolos/convensi dua mode)
  - Hero text: light = `scheme.onPrimary` (cream), dark = `scheme.onSurface` (inkDark) — brightness check lokal hanya di widget hero, bukan untuk paksa mode.
  - `correct_overlay.dart` → TETAP pakai token gelap eksplisit (overlay = standalone `const MaterialApp`, dirancang gelap selalu; di luar mekanika tema app).
- Push HANYA setelah user bilang ya. File final ke `/sdcard/Download/SSR-SPACE/`.

---

### Task 1: Fondasi — prefs, restore noir, wiring main, strings, test

**Files:**
- Modify: `lib/services/app_settings.dart`
- Modify: `lib/theme/app_theme.dart`
- Modify: `lib/main.dart`
- Modify: `lib/utils/strings.dart`
- Modify: `test/app_settings_ext_test.dart`
- Modify: `pubspec.yaml`, `lib/utils/app_info.dart`

**Interfaces:**
- Produces: `themeChoice` (`ValueNotifier<String>`, default `'otomatis'`), `Future<void> setThemeChoice(String v)` (validasi: `'noir'` saja yang diterima, lainnya → `'otomatis'`), `SsrTheme.noir()` (`ThemeData`), token noir di `SsrColors`: `noirBg`, `noirSurface`, `noirRaised`, `noirLine`, `noirInk`, `noirSecondary`.
- Consumes: `tr()` dari strings.dart; `SsrRadius` sekarang (button 12, card 24).

- [ ] **Step 1: Tambah test yang gagal** di `test/app_settings_ext_test.dart`:
  ```dart
  test('theme choice fail-safe + persist', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await loadAppSettings(p);
    expect(themeChoice.value, 'otomatis');
    await setThemeChoice('noir');
    expect(themeChoice.value, 'noir');
    await setThemeChoice('invalid');
    expect(themeChoice.value, 'noir'); // nilai invalid ditolak, tidak merusak state
    SharedPreferences.setMockInitialValues({'app_theme_choice': 'noir'});
    final p2 = await SharedPreferences.getInstance();
    await loadAppSettings(p2);
    expect(themeChoice.value, 'noir');
  });
  ```

- [ ] **Step 2: Run test → FAIL** (`themeChoice` belum ada):
  ```
  flutter test test/app_settings_ext_test.dart
  ```

- [ ] **Step 3: Tambah prefs di `app_settings.dart`** — kunci `_kThemeChoice = 'app_theme_choice'`, notifier `themeChoice`, load di `loadAppSettings` (fallback `'otomatis'`, validasi sama seperti `uiHeroStyle`), setter `setThemeChoice` ikut pola `setUiHeroStyle`.

- [ ] **Step 4: Restore token noir di `app_theme.dart`** — tambah 6 token di `SsrColors` dari commit `0bdeb7b` (`noirBg #0C1210`, `noirSurface #141C18`, `noirRaised #1B2521`, `noirLine #2A3530`, `noirInk #F2EFE6`, `noirSecondary #A8A39A`; `mint`/`rose` sudah ada). Ambil `SsrTheme.noir()` lengkap via `git show 0bdeb7b:lib/theme/app_theme.dart`, taruh di `SsrTheme` (bukan `AppTheme`); radius pakai `SsrRadius` sekarang; `money`/`moneyLarge`/`moneyOnDark` di noir() pakai `SsrColors.noirInk`.

- [ ] **Step 5: Wiring `main.dart`** — di `SsrSpaceApp.build`, bungkus dengan `ValueListenableBuilder<String>(valueListenable: themeChoice, ...)` terluar (sebelum localeCode). Builder memilih:
  ```dart
  final isNoir = theme == 'noir';
  MaterialApp(
    theme: isNoir ? SsrTheme.noir() : AppTheme.light(),
    darkTheme: isNoir ? SsrTheme.noir() : AppTheme.dark(),
    themeMode: ThemeMode.system,
    ...
  )
  ```

- [ ] **Step 6: Strings** — tambah di `_t`: `st_theme` ({'id':'Tema','en':'Theme'}), `th_auto` ({'id':'Otomatis','en':'Automatic'}), `th_noir` ({'id':'Noir','en':'Noir'}), `th_theme_desc` ({'id':'Pilih tampilan aplikasi.','en':'Choose how the app looks.'}).

- [ ] **Step 7: Run test → PASS** (`flutter test test/app_settings_ext_test.dart`).

- [ ] **Step 8: Bump version** — `pubspec.yaml` `version: 2.4.3+26` + `AppInfo.version = '2.4.3+26'`.

- [ ] **Step 9: Commit** — `feat: tema otomatis+noir (prefs, restore noir, wiring main) + test + 2.4.3+26`.

---

### Task 2: Konversi sadar-tema — widgets + overlay (4 file)

**Files:**
- Modify: `lib/widgets/status_chip.dart` (8 situs)
- Modify: `lib/widgets/tx_row.dart` (2 situs)
- Modify: `lib/widgets/pin_field.dart` (2 situs)
- Modify: `lib/widgets/correct_overlay.dart` (7 situs — lihat ruling)

**Interfaces:**
- Consumes: `themeChoice` tidak dipakai di sini; konversi murni `Theme.of(context).colorScheme`.
- Produces: nol (file lain tidak import token spesifik dari file ini).

- [ ] **Step 1: `status_chip.dart`** — `chipAutoBg`/`chipWarnBg`/`goldSoft`/`chipSurplusText` TETAP. `line`/`lineDark` → `scheme.outline`. `emerald` → `scheme.primary`, `rust` → `scheme.error`, `inkSoft`/`inkSoftDark` → `scheme.onSurfaceVariant`. Helper `dark` existing tetap dipakai hanya untuk memilih pasangan token (bukan untuk paksa mode).

- [ ] **Step 2: `tx_row.dart`** — `rust` → `scheme.error`, `goldSoft` TETAP; `ColorFilter.mode(rust)` → `scheme.error`; `const Color(0xFF7A5E14)` TETAP (chip surplus text).

- [ ] **Step 3: `pin_field.dart`** — `rust` → `scheme.error` (2 situs).

- [ ] **Step 4: `correct_overlay.dart`** — RULING: TETAP pakai token eksplisit. Overlay adalah `const MaterialApp` standalone (entry `overlayMain`), tidak mewarisi tema app, dan memang dirancang gelap selalu sebagai alat koreksi instan. Konversi di sini akan merusak overlay tanpa mengubah tampilan app. Catat alasan di komentar 1 baris.

- [ ] **Step 5: Verifikasi lokal** — `dart format` bersih di 4 file; grep nol `AppColors.` tersisa di 4 file ini (kecuali correct_overlay yang token gelapnya sengaja tetap).

- [ ] **Step 6: Commit** — `refactor: widgets sadar-tema via colorScheme`.

---

### Task 3: Konversi sadar-tema — screens keuangan (3 file)

**Files:**
- Modify: `lib/screens/beranda/beranda_screen.dart` (5 situs)
- Modify: `lib/screens/transaksi/transactions_screen.dart` (2 situs)
- Modify: `lib/screens/budget/budgets_screen.dart` (14 situs)

- [ ] **Step 1: `beranda_screen.dart`** — hero: bg `emeraldDeep` TETAP; hero text light `scheme.onPrimary` (cream), dark `scheme.onSurface` (inkDark) via brightness check lokal di hero widget saja; `emerald` fill/teks → `scheme.primary`; `gold` TETAP (tag SURPLUS); `inkDark` sisa → `scheme.onSurface`.

- [ ] **Step 2: `transactions_screen.dart`** — `rust` → `scheme.error` (2 situs, termasuk `.withValues(alpha:)`).

- [ ] **Step 3: `budgets_screen.dart`** — `rust` → `scheme.error`, `emerald` → `scheme.primary`, `gold` TETAP (urgent + border + fill), `bgDark` → `scheme.surfaceContainerLowest` (bg kartu dark), `goldSoft` TETAP. Helper warna (`_ringColor` dsb.) mengembalikan `Color` dari scheme; pastikan `.withValues(alpha:)` tetap valid.

- [ ] **Step 4: Verifikasi lokal** — `dart format` bersih; grep nol `AppColors.` tersisa di 3 file.

- [ ] **Step 5: Commit** — `refactor: screens keuangan sadar-tema via colorScheme`.

---

### Task 4: Konversi sadar-tema — screens laporan, dompet, kategori, auth (6 file)

**Files:**
- Modify: `lib/screens/laporan/reports_screen.dart` (13 situs)
- Modify: `lib/screens/dompet/wallets_screen.dart` (2 situs)
- Modify: `lib/screens/dompet/wallet_detail_screen.dart` (3 situs)
- Modify: `lib/screens/lainnya/categories_screen.dart` (3 situs)
- Modify: `lib/screens/auth/splash_screen.dart` (1 situs)
- Modify: `lib/screens/auth/intro_consent_screen.dart` (1 situs)

- [ ] **Step 1: `reports_screen.dart`** — `emerald` → `scheme.primary` (masuk), `rust` → `scheme.error` (keluar), `gold` TETAP (tabungan), `goldSoft` TETAP; donut + legenda + ringkasan ikut mapping; `SsrType.moneyMedium.copyWith(color: rust)` → `scheme.error`.

- [ ] **Step 2: `wallets_screen.dart` + `wallet_detail_screen.dart`** — `gold` TETAP (semua situs di 2 file ini = aksen tabungan/emas).

- [ ] **Step 3: `categories_screen.dart`** — `emerald` → `scheme.primary`, `rust` → `scheme.error`, `gold` TETAP.

- [ ] **Step 4: `splash_screen.dart` + `intro_consent_screen.dart`** — `gold` TETAP (garis brand 56px).

- [ ] **Step 5: Verifikasi lokal** — `dart format` bersih; grep nol `AppColors.` tersisa di 6 file.

- [ ] **Step 6: Commit** — `refactor: screens laporan/dompet/kategori/auth sadar-tema`.

---

### Task 5: UI settings — kartu Tema

**Files:**
- Modify: `lib/screens/lainnya/settings_screen.dart`

**Interfaces:**
- Consumes: `themeChoice` notifier, `setThemeChoice`, `tr('st_theme')`/`tr('th_auto')`/`tr('th_noir')`, `ssrSegmentedStyle(context)` dari `lib/widgets/tx_type_selector.dart`.
- Produces: `_ThemeCard` widget privat di settings_screen.dart.

- [ ] **Step 1: Tambah `_ThemeCard`** meniru pola `_LangCard` (LabeledSectionCard + SegmentedButton + `ssrSegmentedStyle`), segments `otomatis`/`noir` pakai label `tr('th_auto')`/`tr('th_noir')`, subtitle `tr('th_theme_desc')`. Ganti langsung teraplikasi via notifier (pengguna tidak perlu simpan; pola sama dengan `maskAmounts`).

- [ ] **Step 2: Pasang `_ThemeCard()`** di seksi Tampilan settings (dekat `_HeroStyleCard`).

- [ ] **Step 3: Verifikasi** — `dart format` bersih; pastikan `tr()` TIDAK di dalam `const` (pelajaran i18n: analyze fatal).

- [ ] **Step 4: Commit** — `feat: picker tema di settings (otomatis/noir)`.

---

### Task 6: Langkah pilih tema saat setup user baru

**Files:**
- Create: `lib/screens/auth/theme_step_screen.dart`
- Modify: `lib/screens/auth/intro_consent_screen.dart`

**Interfaces:**
- Consumes: `setThemeChoice`, `tr()` kunci Task 1, `PrimaryButton`, `SsrTheme`/`SsrRadius`/`SsrSpace`.
- Produces: `ThemeStepScreen` ({required SessionService session, bool skipAuth}) — satu layar, 2 kartu opsi (Otomatis default tercentang / Noir), tombol `tr('in_next')` lanjut, bisa lewati tanpa memilih (tetap Otomatis).

- [ ] **Step 1: Alur** — di `_IntroConsentScreenState._agree()`: setelah `consent_v1` berhasil ditulis, navigasi ke `ThemeStepScreen` (bukan langsung `SplashScreen`); ThemeStepScreen tombol lanjut → `pushReplacement` `SplashScreen(session, skipAuth)`. User lama tidak pernah lewat IntroConsent → tidak melihat langkah ini (spec §4b).

- [ ] **Step 2: Bikin `ThemeStepScreen`** — visual meniru bahasa IntroConsent (Scaffold + SafeArea + PrimaryButton bawah, radius `SsrRadius.card`, warna via colorScheme); dua kartu pilih-satu (RadioListTile atau InkWell + Icon check), default `otomatis`; `onChanged` langsung `setThemeChoice`. Tanpa appbar kembali (langkah linear), tapi boleh tambah teks kecil "Lewati" yang sama dengan lanjut.

- [ ] **Step 3: Wiring** — import + ganti target navigasi di `_agree()`.

- [ ] **Step 4: Verifikasi** — `dart format` bersih; grep nol em dash di file baru.

- [ ] **Step 5: Commit** — `feat: langkah pilih tema di setup user baru`.

---

### Task 7: Docs lokal + persiapan push

**Files:**
- Modify: `AUDIT.md` (changelog §7)
- Modify: `AGENTS.md` (baris status)

- [ ] **Step 1: Catat changelog** di AUDIT.md §7: commit Task 1-6, versi 2.4.3+26, ringkas isi (prefs, restore noir, wiring main, 127 situs sadar-tema, picker settings, theme step).
- [ ] **Step 2: Catat status** di AGENTS.md (fitur baru + ruling overlay + ruling hero text).
- [ ] **Step 3: Commit docs** — digabung dengan commit terakhir (jangan docs sendirian).
- [ ] **Step 4: Push + pantau CI** — `gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status` sampai hijau.
- [ ] **Step 5: APK arm64** — `gh run download <run-id> -n ssr-space-apk` → simpan varian arm64 ke `/sdcard/Download/SSR-SPACE/`.
- [ ] **Step 6: Verifikasi device user** — SS tiap layar utama dalam 2 mode (terang sistem + Noir), terapkan checklist AUDIT §5 (R-34/R-35 antislop).

---

## Aturan antislop yang berlaku saat eksekusi

- R-34: kedua mode (terang + Noir) wajib full function; kontras Noir pakai ulang tabel terukur dari New Design Emerald Noir; pasangan baru diukur.
- R-25: teks AA 4.5:1 (normal) / 3:1 (besar) di kedua mode.
- R-26: tiap kontrol interaktif berperilakuan nyata (pilih tema langsung apply).
- R-02: copy Indonesia tanpa em dash.
- Delivery Gate antislop (core) dijalankan sebelum laporan akhir.

## Ruling controller (dibuat sebelum eksekusi)

1. **`correct_overlay.dart` tidak dikonversi** — overlay adalah standalone `const MaterialApp` (entry `overlayMain`) yang tidak mewarisi tema app dan memang dirancang gelap selalu. Biaya bila salah: kalau dikonversi pakai colorScheme default (light), overlay jadi terang = regresi visual yang sudah benar sekarang.
2. **Hero text via brightness check lokal** — light `scheme.onPrimary` (cream), dark `scheme.onSurface` (inkDark). Brightness dibaca hanya untuk warna teks di atas hero `emeraldDeep` (yang tetap), bukan untuk paksa mode.
3. **Radius noir memakai `SsrRadius` sekarang** (button 12, card 24) — restore `0bdeb7b` menulis radius lama (14/16); konsisten dengan app lebih penting daripada restore byte-identik.
4. **`st_theme`** ditambah sebagai kunci label kartu (spec hanya mewajibkan `th_auto`/`th_noir`).
