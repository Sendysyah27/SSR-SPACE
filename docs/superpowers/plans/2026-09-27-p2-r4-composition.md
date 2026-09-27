# P2-R4 Composition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strip komposisi aset Liquid, Savings, Investments di layar Dompet dari data saldo yang sudah ada, tanpa migration.

**Architecture:** Fungsi murni pemetaan tipe ke bucket plus penjumlahan dari `wallet_balance`, strip reuse `SectionCard` dan pola donut Laporan, opsi tipe baru hanya di dropdown form dan strings.

**Tech Stack:** Flutter stable, `fl_chart` yang sudah ada untuk donut mini, Dart murni untuk logika, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-27-p2-r4-composition.md`

## Global Constraints

- Tanpa migration Supabase (kolom `wallets.type` text bebas tanpa check).
- Tanpa dependensi pubspec baru, tanpa aset baru (art fallback cash dulu).
- Jangan sentuh gate `_onEvent`, RLS, atau TX-code.
- Copy lewat `tr()` plus EN; tanpa em dash.
- Nominal lewat `amt()`; sembunyi bila kurang dari 2 bucket berisi.
- `build()` di bawah 50 baris; `flutter analyze` 0 issue; verifikasi penuh via CI.
- Version Skema A bila push digabung batch: satu bump di akhir.

---

## File map

- Baru: `lib/services/wallet_composition.dart` (murni).
- Baru: `test/wallet_composition_test.dart` (5 expects).
- Ubah: `lib/utils/strings.dart` (label Savings, Investments, subtitle).
- Ubah: `lib/screens/dompet/wallets_screen.dart` (strip komposisi).
- Ubah: form dompet (dropdown tipe tambah `savings` dan `investment`, file sama dengan `wallets_screen.dart` state form).

---

### Task 1: Logika murni bucket plus compose dan test

**Files:**
- Create: `lib/services/wallet_composition.dart`
- Test: `test/wallet_composition_test.dart`

**Interfaces:**
- Consumes: tipe dompet string, peta saldo per wallet id, peta tipe per wallet id.
- Produces: `enum AssetBucket { liquid, savings, investments }`, `AssetBucket bucketOf(String? type)`, `class Composition { double liquid, savings, investments; double liquidPct, savingsPct, investmentsPct; int get filledBuckets; bool get showStrip; }`, `Composition composeComposition(Map<String, double> balances, Map<String, String> types)`.

- [ ] **Step 1: Tulis test yang gagal**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/wallet_composition.dart';

void main() {
  test('pemetaan tipe ke bucket', () {
    expect(bucketOf('savings'), AssetBucket.savings);
    expect(bucketOf('Savings'), AssetBucket.savings);
    expect(bucketOf('investment'), AssetBucket.investments);
    expect(bucketOf('cash'), AssetBucket.liquid);
    expect(bucketOf('ewallet'), AssetBucket.liquid);
    expect(bucketOf('bank'), AssetBucket.liquid);
    expect(bucketOf('aneh'), AssetBucket.liquid);
    expect(bucketOf(null), AssetBucket.liquid);
  });

  test('penjumlahan dan persen benar', () {
    final c = composeComposition(
      {'a': 60000, 'b': 30000, 'c': 10000},
      {'a': 'cash', 'b': 'savings', 'c': 'investment'},
    );
    expect(c.liquid, 60000);
    expect(c.savings, 30000);
    expect(c.investments, 10000);
    expect(c.liquidPct, 0.6);
    expect(c.showStrip, isTrue);
  });

  test('satu bucket berisi berarti sembunyi', () {
    final c = composeComposition({'a': 50000}, {'a': 'cash'});
    expect(c.filledBuckets, 1);
    expect(c.showStrip, isFalse);
  });

  test('total nol persen nol tanpa crash', () {
    final c = composeComposition({'a': 0}, {'a': 'cash'});
    expect(c.liquidPct, 0);
    expect(c.showStrip, isFalse);
  });

  test('tipe hilang ikut liquid', () {
    final c = composeComposition({'a': 10000}, {});
    expect(c.liquid, 10000);
    expect(c.showStrip, isFalse);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/wallet_composition_test.dart` via CI.
Expected: FAIL file belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

```dart
enum AssetBucket { liquid, savings, investments }

/// savings ke Savings, investment ke Investments, sisanya Liquid.
/// Case-insensitive, null dan tak dikenal ke Liquid.
AssetBucket bucketOf(String? type) {
  final t = (type ?? '').trim().toLowerCase();
  if (t == 'savings') return AssetBucket.savings;
  if (t == 'investment' || t == 'investments') return AssetBucket.investments;
  return AssetBucket.liquid;
}

class Composition {
  final double liquid;
  final double savings;
  final double investments;
  const Composition({required this.liquid, required this.savings, required this.investments});

  double get total => liquid + savings + investments;
  double get liquidPct => total <= 0 ? 0 : liquid / total;
  double get savingsPct => total <= 0 ? 0 : savings / total;
  double get investmentsPct => total <= 0 ? 0 : investments / total;
  int get filledBuckets =>
      (liquid > 0 ? 1 : 0) + (savings > 0 ? 1 : 0) + (investments > 0 ? 1 : 0);
  bool get showStrip => filledBuckets >= 2;
}

Composition composeComposition(
  Map<String, double> balances,
  Map<String, String> types,
) {
  var l = 0.0;
  var s = 0.0;
  var v = 0.0;
  balances.forEach((id, bal) {
    switch (bucketOf(types[id])) {
      case AssetBucket.savings:
        s += bal;
        break;
      case AssetBucket.investments:
        v += bal;
        break;
      case AssetBucket.liquid:
        l += bal;
        break;
    }
  });
  return Composition(liquid: l, savings: s, investments: v);
}
```

- [ ] **Step 4: Verifikasi lokal lalu CI**

Run lokal: `dart` murni untuk 5 skenario.
Run CI: `flutter test test/wallet_composition_test.dart` PASS.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/wallet_composition.dart test/wallet_composition_test.dart
git commit -m "feat: komposisi aset liquid savings investments plus test"
```

---

### Task 2: Strip di Dompet plus tipe baru dan strings

**Files:**
- Modify: `lib/utils/strings.dart`
- Modify: `lib/screens/dompet/wallets_screen.dart`

**Interfaces:**
- Consumes: `composeComposition` dari Task 1, `balances` dan `items` yang sudah dimuat `_load`, `amt()`, `tr()`, `PieChart` pola `reports_screen.dart`.
- Produces: `_CompositionStrip` yang tampil hanya bila `showStrip` true, plus opsi dropdown tipe `savings` dan `investment` di form dompet.

- [ ] **Step 1: Tambah strings dulu**

```dart
'w_savings': {'id': 'Tabungan', 'en': 'Savings'},
'w_investment': {'id': 'Investasi', 'en': 'Investment'},
'comp_title': {'id': 'Komposisi aset', 'en': 'Asset mix'},
'comp_sub': {'id': 'Posisi saldo per kelompok', 'en': 'Balance by group'},
'comp_liquid': {'id': 'Likuid', 'en': 'Liquid'},
```

- [ ] **Step 2: Pastikan gagal sebelum strip ada**

Pakai `tr('comp_title')` di build tanpa widget; CI analyze menandai wiring belum lengkap.

- [ ] **Step 3: Tulis strip minimal dan opsi tipe**

```dart
// di _load selesai, bangun sekali saat render:
final comp = composeComposition(
  {for (final b in balances) b.walletId: b.balance},
  {for (final w in items) w.id: w.type},
);
if (comp.showStrip) _CompositionStrip(comp: comp),
```

`_CompositionStrip` adalah `StatelessWidget` di file yang sama (di bawah 50 baris): `SectionCard` berisi judul, subtitle jujur, tiga baris Liquid, Savings, Investments dengan nominal `amt()` dan persen, plus donut mini reuse pola `PieChart` dari laporan (touch mati, hanya iris lebih dari 0). Saldo gagal dimuat (`balancesOk` false): jangan tampilkan strip. Form tambah dua item dropdown memakai `tr('w_savings')` dan `tr('w_investment')` dengan value `savings` dan `investment`.

- [ ] **Step 4: Verifikasi**

Run: `flutter analyze` 0 issue dan `flutter test` hijau via CI; cek device: workspace lama tanpa tipe baru membuat strip sembunyi; tambah dompet Tabungan berisi membuat strip muncul; mask ON membuat angka jadi placeholder; EN mengganti label.
Expected: PASS.

- [ ] **Step 5: Commit plus version dan docs lokal**

```bash
git add lib/utils/strings.dart lib/screens/dompet/wallets_screen.dart
git commit -m "feat: strip komposisi aset di dompet"
```

Bila batch R1-R4 satu push: bump sekali di akhir (`pubspec.yaml` dan `lib/utils/app_info.dart` ke `2.4.0+23`, catat `AUDIT.md` §7 dan `AGENTS.md` lokal saja).
