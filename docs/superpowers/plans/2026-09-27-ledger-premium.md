# Ledger Premium Implementation Plan (otoritas prompt user)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gantikan visual noir dengan Ledger Premium setia prompt (light-first cream + dark variant) tanpa mengubah logika apa pun.

**Architecture:** Token dulu (`AppColors` exact + `AppTheme.light()/dark()` + wiring `main.dart`), lalu ikon SVG, komponen, layar, sapu sisa. Noir yang sudah push ditimpa dalam batch ini; satu push di akhir.

**Tech Stack:** Flutter stable (Material 3), `flutter_svg` existing, font bundel existing, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-27-ledger-premium-design.md` (otoritas; prompt + HTML user)

## Global Constraints

- Visual-only: tanpa migration, tanpa tabel/RLS baru, tanpa dep pubspec baru (`google_fonts` dan `phosphor_flutter` DILARANG oleh adaptasi tercatat).
- Jangan sentuh gate `_onEvent`, TX-code, alur data, provider, navigasi.
- Copy identik kecuali format subtitle TxRow `{date} · {time} · {tx_id}` dan prefix `+`/U+2212.
- Nominal Fraunces, selainnya PJS; tabular untuk angka.
- Gold hanya 3 titik (SURPLUS, satu ring urgent, segmen tabungan).
- Tanpa hex di file widget di luar token; tanpa baca `platformBrightness` di widget.
- `build()` < 50; tanpa em dash; `flutter analyze` 0 issue (info fatal).
- Version: `2.4.1+24` ke `2.4.2+25` (identik pubspec + AppInfo) di task akhir.
- Push hanya oleh controller setelah review CLEAN dan izin user.

## Ruling scope

Satu plan, task sekuensial (token dipakai semua task berikutnya). Tanpa paralel.

---

## File map

- Token: `lib/theme/app_theme.dart` (tambah `AppColors` + `AppTheme.light()/dark()`), `lib/main.dart` (theme + darkTheme + themeMode system), `DESIGN.md`.
- Ikon: `assets/illustrations/cat_*.svg` (SUDAH diekstrak 12 file), `lib/services/category_icons.dart` (tambah `svgForCategory`), `lib/widgets/tx_row.dart`, picker kategori.
- Komponen: `section_card.dart`, `status_chip.dart`, `primary_button.dart`, `pin_field.dart`, `lib/theme/app_typography.dart` (cek).
- Layar: beranda, budget, laporan, lalu sapu (lainnya, dompet, transaksi, auth, workspace, sheet) dari sisa noir ke ledger.

---

### Task 1: Token AppColors plus light/dark plus wiring

**Files:** Modify `lib/theme/app_theme.dart`, `lib/main.dart`, `DESIGN.md`.

**Interfaces:** Produces `AppColors` (emerald `0xFF0E4B44`, emeraldDeep `0xFF0A332E`, gold `0xFFC9A227`, goldSoft `0xFFEDE2C1`, rust `0xFFB23A2E`, cream `0xFFF6F4EC`, ink `0xFF171A19`, inkSoft `0xFF5B6360`, line `0xFFE4E0D4`, bgDark `0xFF12100C`, surfaceDark `0xFF1C1A16`, inkDark `0xFFF1EEE6`, inkSoftDark `0xFFA6A296`, lineDark `0xFF2C2823`); `AppTheme.light()` dan `AppTheme.dark()`; main memakai `theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ThemeMode.system`.

- [ ] Step 1: Tulis `AppColors` exact + `light()` (scaffold cream, surface putih, primary emerald, onPrimary cream, error rust, outline line; input fill putih border line focus emerald; radius ikut Task 3) + `dark()` (scaffold bgDark, surface surfaceDark, primary emerald, onPrimary cream, error rust terang? pakai rust yang sama + teks inkDark; outline lineDark). `SsrTheme.noir()` dan token noir dipertahankan hingga migrasi selesai (dihapus Task 7).
- [ ] Step 2: Wiring main + DESIGN.md (palet prompt, dial tetap 2/2/1, motif ledger, catatan otoritas prompt).
- [ ] Step 3: Tabel kontras (skrip dart /tmp, pasangan: ink/cream, inkSoft/cream, cream/emerald, cream/emeraldDeep, inkDark/bgDark, inkSoftDark/bgDark, `#7A5E14`/goldSoft, rust/cream, cream/rust). Gagal → sesuaikan hanya nilai non-exact? Nilai exact prompt TIDAK boleh diubah; bila gagal, catat pasangan + pemakaian amannya (misal teks di atas tint, bukan solid) sebagai ruling di laporan.
- [ ] Step 4: Commit `git add lib/theme/app_theme.dart lib/main.dart DESIGN.md && git commit -m "design: token ledger premium light dark"`. JANGAN push.

### Task 2: Ikon SVG kategori

**Files:** Modify `lib/services/category_icons.dart`, `lib/widgets/tx_row.dart`, picker kategori (`category_chips.dart` + pemakai `iconForCategory` — grep dulu).

**Interfaces:** Produces `String svgForCategory(String? category)` (cabang existing dipertahankan + wifi sebelum tagihan + tabungan/saving ke save; income/topup ke wallet, transfer ke transfer, fallback other). Konsumen: TxRow + picker via `SvgPicture.asset(path, width: 19, colorFilter: warna)`.

- [ ] Step 1: Tulis `svgForCategory` + ganti TxRow ke wadah 38x38 goldSoft radius 11 + glif `#7A5E14`; baris Keluar wadah tint rust + glif rust. Format subtitle `{date} · {time} · {code}` dan nominal prefix `+`/U+2212 (sanitize: code null → tanpa trailing).
- [ ] Step 2: Picker kategori ikut wadah yang sama. Grep sisa pemakai `iconForCategory` font; alihkan atau catat.
- [ ] Step 3: Commit `git commit -m "design: ikon kategori SVG ledger"`. JANGAN push.

### Task 3: Radius dan komponen dasar

**Files:** Modify `lib/theme/app_theme.dart` (`SsrRadius`: card 24, tile/row 12, chip pill 999, button 12, input 12, hero 24), `section_card.dart` (bg putih/surfaceDark, border line 1px, radius 24, padding 20/18, shadow), `status_chip.dart` (pill 12/5; surplus goldSoft `#7A5E14` CAPS; auto `#E4EFEA` emerald; warning `#F6E4E1` rust), `primary_button.dart` (emerald/cream 15/600 radius 12 padding 20/15 flat full-width disabled 40%), `pin_field.dart` (kotak 38x46 border 1.5 line radius 10 fokus emerald 2px isi dot Fraunces 18 gap 8).

- [ ] Step 1: Terapkan per komponen (nilai exact prompt).
- [ ] Step 2: Commit `git commit -m "design: radius dan komponen ledger"`. JANGAN push.

### Task 4: Beranda hero

**Files:** Modify `lib/screens/beranda/beranda_screen.dart`.

- [ ] Step 1: Hero emeraldDeep (ganti hitam murni); tag SURPLUS gold pill kiri atas; nominal Fraunces 32 cream; Masuk/Keluar label 12 cream 70% + nilai Fraunces 14 penuh. Blob abu dibuang (flat atau hairline emas 1px). Rumus dan reload tetap.
- [ ] Step 2: Commit `git commit -m "design: beranda ledger premium"`. JANGAN push.

### Task 5: Budget ring dan Laporan donut

**Files:** Modify `lib/screens/budget/budgets_screen.dart`, `lib/screens/laporan/reports_screen.dart`.

- [ ] Step 1: Ring emerald on-track; gold hanya satu kategori paling mendesak bulan ini (definisi: persen tertinggi di bawah 100? atau di atas 80% terdekat limit — pilih satu, catat di laporan, konsisten). Copy pace tetap. Donut emerald/rust/gold; rekap kategori reuse layout TxRow (ikon + label + nominal).
- [ ] Step 2: Commit `git commit -m "design: budget laporan ledger premium"`. JANGAN push.

### Task 6: Sapu sisa + teal nol + bump + docs

**Files:** Semua layar dan widget tersisa yang masih baca token noir atau teal lama (`grep 0F766E`, `noir`, `accent`/`danger` lama); `pubspec.yaml`, `app_info.dart`, `AUDIT.md`, `AGENTS.md`.

- [ ] Step 1: Migrasi sisa ke AppColors; verifikasi `grep -r 0F766E lib/` NOL, `SsrColors.noir` pemakaian NOL (definisi boleh tinggal bila tak dipakai? TIDAK: hapus token noir + `noir()` agar satu kebenaran; pastikan tak ada referensi dulu via grep).
- [ ] Step 2: Checklist penerimaan prompt satu per satu dengan bukti (file:baris): tanpa hitam murni, tanpa teal, Rp Fraunces, radius hierarki, ikon SVG, gold 3 titik (grep `gold` dan justifikasi tiap situs), light+dark terdefinisi.
- [ ] Step 3: Bump `2.4.1+24` ke `2.4.2+25` + changelog + status. Commit (JANGAN push).

## Self-review

- Cakupan: §1 ke T1, §2 ke T1+T3, §3 ke T2, §4 ke T3, §5 ke T4+T5, §6 ke T1, §7 ke T6. Penuh.
- Placeholder: nol. Nilai exact di tiap task. Inkonsistensi T1-vs-T6 (noir dihapus) disengaja dan eksplisit.
