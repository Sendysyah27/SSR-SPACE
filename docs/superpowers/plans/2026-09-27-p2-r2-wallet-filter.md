# P2-R2 Wallet Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Laporan bisa difilter per dompet, semua turunan (donut, Top-8, total, hints) ikut pilihan.

**Architecture:** Fungsi murni `filterByWallet` di file baru, state session-only di `ReportsScreen`, tidak ada prefs atau query baru. Filter jalan di memori dari `listMonth` yang sudah ada.

**Tech Stack:** Flutter stable, Dart murni untuk logika, flutter_test, tanpa prefs baru.

**Spec:** `docs/superpowers/specs/2026-09-27-p2-r2-wallet-filter.md`

## Global Constraints

- Tanpa migration Supabase, tanpa tabel atau RLS baru.
- Tanpa dependensi pubspec baru.
- Jangan sentuh `lib/services/notif_track_service.dart` gate `_onEvent`, RLS, atau TX-code.
- Copy lewat `tr()` plus EN; tanpa em dash.
- Nominal lewat `amt()`; tanggal lewat helper yang ada.
- `build()` tetap di bawah 50 baris dengan ekstraksi widget bila perlu.
- `flutter analyze` 0 issue; flutter tidak ada di Termux jadi verifikasi penuh via CI.
- Version Skema A bila push digabung batch: satu bump di akhir.

---

## File map

- Baru: `lib/services/wallet_filter.dart` (murni).
- Baru: `test/wallet_filter_test.dart` (4 expects).
- Ubah: `lib/utils/strings.dart` (2 kunci).
- Ubah: `lib/screens/laporan/reports_screen.dart` (state filter plus terapkan ke semua turunan).

---

### Task 1: Logika murni filterByWallet plus test

**Files:**
- Create: `lib/services/wallet_filter.dart`
- Test: `test/wallet_filter_test.dart`

**Interfaces:**
- Consumes: `SaasTransaction` (`walletId`, `toWalletId`).
- Produces: `List<SaasTransaction> filterByWallet(List<SaasTransaction> items, String? walletId)` (null atau kosong berarti semua, kembalikan salinan; transfer ikut bila sisi asal atau sisi tujuan cocok).

- [ ] **Step 1: Tulis test yang gagal**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/wallet_filter.dart';

SaasTransaction tx(String id, String type, {String? w, String? to}) {
  return SaasTransaction(
    id: id, orgId: 'o', type: type, amount: 10000,
    walletId: w, toWalletId: to,
  );
}

void main() {
  test('null berarti semua dan salinan baru', () {
    final src = [tx('a', 'out', w: 'w1')];
    final out = filterByWallet(src, null);
    expect(out.length, 1);
    expect(identical(out, src), isFalse);
  });

  test('filter sisi asal dan sisi tujuan transfer', () {
    final items = [
      tx('a', 'out', w: 'w1'),
      tx('b', 'in', w: 'w2'),
      tx('c', 'transfer', w: 'w1', to: 'w2'),
      tx('d', 'transfer', w: 'w2', to: 'w1'),
    ];
    expect(filterByWallet(items, 'w1').map((t) => t.id), ['a', 'c', 'd']);
  });

  test('id asing menghasilkan kosong', () {
    final items = [tx('a', 'out', w: 'w1')];
    expect(filterByWallet(items, 'wx'), isEmpty);
  });

  test('string kosong sama dengan semua', () {
    final items = [tx('a', 'out', w: 'w1')];
    expect(filterByWallet(items, '').length, 1);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/wallet_filter_test.dart` via CI.
Expected: FAIL file implementasi belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

```dart
import '../models/transaction.dart';

/// Filter list ke satu dompet. Null atau kosong berarti semua.
/// Transfer ikut bila walletId atau toWalletId cocok. Kembalikan salinan.
List<SaasTransaction> filterByWallet(
  List<SaasTransaction> items,
  String? walletId,
) {
  if (walletId == null || walletId.isEmpty) {
    return List<SaasTransaction>.of(items);
  }
  return items.where((t) {
    return t.walletId == walletId || t.toWalletId == walletId;
  }).toList();
}
```

- [ ] **Step 4: Verifikasi lokal lalu CI**

Run lokal: `dart` murni untuk 4 skenario (file tanpa import Flutter).
Run CI: `flutter test test/wallet_filter_test.dart` PASS.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/wallet_filter.dart test/wallet_filter_test.dart
git commit -m "feat: filter laporan per dompet plus test"
```

---

### Task 2: State filter di ReportsScreen plus strings

**Files:**
- Modify: `lib/utils/strings.dart`
- Modify: `lib/screens/laporan/reports_screen.dart`

**Interfaces:**
- Consumes: `filterByWallet` dari Task 1, `walletNames` yang sudah dimuat di `_load`.
- Produces: state `String? filterWallet` (null sama dengan Semua); dropdown di atas ringkasan; semua turunan memakai `filtered = filterByWallet(items, filterWallet)` sebelum hitung total, donut, Top-8, dan list.

- [ ] **Step 1: Tambah strings dulu**

```dart
'r_filter_all': {'id': 'Semua dompet', 'en': 'All wallets'},
'r_filter_wallet': {'id': 'Dompet', 'en': 'Wallet'},
```

- [ ] **Step 2: Pastikan dropdown gagal sebelum state ada**

Tambahkan pemakaian `tr('r_filter_all')` di build tanpa state; CI analyze akan menunjukkan wiring belum lengkap. Ekspektasi gagal di sini berarti kunci terbaca.

- [ ] **Step 3: Tulis wiring minimal**

```dart
String? filterWallet;

// di build, di atas ringkasan:
DropdownButtonFormField<String?>(
  value: filterWallet,
  decoration: InputDecoration(labelText: tr('r_filter_wallet')),
  items: [
    DropdownMenuItem<String?>(value: null, child: Text(tr('r_filter_all'))),
    for (final e in walletNames.entries)
      DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
  ],
  onChanged: (v) => setState(() => filterWallet = v),
);

// semua hitungan memakai:
final filtered = filterByWallet(items, filterWallet);
```

Dompet yang sudah dihapus: bila `filterWallet` tidak ada di `walletNames`, tampilkan sebagai Semua (fail-open) dengan cara: saat `_load` selesai, bila id tak dikenal set `filterWallet = null`. Ekstraksi widget bila `build()` melewati 50 baris.

- [ ] **Step 4: Verifikasi**

Run: `flutter analyze` 0 issue dan `flutter test` hijau via CI; cek device: pilih dompet mengubah donut, Top-8, total, dan list; dompet kosong menampilkan EmptyView lama; ganti bulan mempertahankan pilihan.
Expected: PASS.

- [ ] **Step 5: Commit plus version dan docs lokal**

```bash
git add lib/utils/strings.dart lib/screens/laporan/reports_screen.dart
git commit -m "feat: filter dompet di laporan"
```

Bila batch R1-R4 satu push: bump sekali di akhir (`pubspec.yaml` dan `lib/utils/app_info.dart` ke `2.4.0+23`, catat `AUDIT.md` §7 dan `AGENTS.md` lokal saja).
