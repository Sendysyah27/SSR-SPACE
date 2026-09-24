# Edit/Hapus Transaksi + Saldo Dompet (A1+A2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** User bisa edit/hapus transaksi dari list, dan saldo per dompet tampil di layar Dompet + dropdown form (view SQL `wallet_balance`).

**Architecture:** Edit in-place di `transactions_screen` (`_editing` + `TransactionService.update`/`delete`, RLS `member tx` sudah FOR ALL). Saldo dari view Postgres `wallet_balance` (`security_invoker`, `migration_09`), di-query via `WalletService.balances`. Validasi form di helper pure `validateTxInput` (TDD).

**Tech Stack:** Flutter (stable) + Supabase Postgres RLS + `shared_preferences` + `flutter_test` (CI only; **flutter tidak ada di Termux**, `dart` lokal saja).

**Spec:** `docs/superpowers/specs/2026-09-24-edit-tx-wallet-balance-design.md`

## Global Constraints

- Versi target: `2.3.4+16` (ubah `pubspec.yaml` di Task 8).
- Migration berikutnya: `supabase/migration_09_wallet_balance.sql` (jangan edit migration lama).
- RLS: **jangan** bikin policy SELECT `org_members` yang subquery ke `org_members` (recursion).
- Copy UI: Bahasa Indonesia, **tanpa em dash `—` (R-02)**, tanpa emoji, CTA spesifik.
- Uang: selalu `rp()` + `SsrTheme.money` (tabular).
- Palette: kertas `#FAFAF7`, zamrud `#0F766E`, danger `#B3261E` (danger selalu dengan label kata), sekunder `#5F5E5B`.
- Radius design system: ElevatedButton 14 / input 12 (jangan pill seragam baru).
- MOTION 1: tanpa animasi kustom; tanpa glow/gradient baru.
- Tap target: tombol aksi min height 48.
- Field **tidak** di-update saat edit tx: `code`, `source_package`, `source_hash`, `created_by`, `created_at`, `org_id`.
- Delivery Gate antislop (spec §7) wajib PASS sebelum serah APK.
- Test lokal: **tidak bisa** `flutter test` di Termux → tulis test, push, pantau CI.
- Commit message: `feat:` / `fix:` / `chore:` EN atau ID konsisten.
- Jangan hardcode secret.

---

### Task 1: Migration view `wallet_balance`

**Files:**
- Create: `supabase/migration_09_wallet_balance.sql`

**Interfaces:**
- Consumes: tabel `public.wallets`, `public.transactions` (kolom `org_id`, `wallet_id`, `to_wallet_id`, `type`, `amount`).
- Produces: view `public.wallet_balance(org_id uuid, wallet_id uuid, balance numeric)` — dipakai Task 5.

- [ ] **Step 1: Tulis file migration**

Isi file `supabase/migration_09_wallet_balance.sql` (persis):

```sql
-- migration_09: view saldo per dompet (Sprint A2)
-- Jalankan di Supabase Dashboard → SQL Editor SEBELUM pakai APK baru.

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

- [ ] **Step 2: Verifikasi sintaks (mental / baca ulang)**

Checklist: `security_invoker = true` ada; hanya `grant select`; LEFT JOIN + COALESCE; transfer kedua cabang (− asal, + tujuan).

- [ ] **Step 3: Commit**

```bash
git add supabase/migration_09_wallet_balance.sql
git commit -m "feat: migration_09 wallet_balance view"
```

**Catatan ke user (di serah akhir):** wajib jalankan SQL ini di Supabase Dashboard sebelum fitur saldo dipakai.

---

### Task 2: Model `WalletBalance` + test

**Files:**
- Create: `lib/models/wallet_balance.dart`
- Test: `test/wallet_balance_test.dart`

**Interfaces:**
- Consumes: row view `wallet_balance` (key `wallet_id`, `balance`).
- Produces:
  - `class WalletBalance { final String walletId; final double balance; const WalletBalance({required this.walletId, required this.balance}); }`
  - `factory WalletBalance.fromMap(Map<String, dynamic> map)`
- Dipakai: Task 5 `WalletService.balances`, Task 6 dropdown, Task 7 wallets screen.

- [ ] **Step 1: Tulis test gagal**

`test/wallet_balance_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/wallet_balance.dart';

void main() {
  test('fromMap int balance', () {
    final b = WalletBalance.fromMap({'wallet_id': 'w1', 'balance': 100000});
    expect(b.walletId, 'w1');
    expect(b.balance, 100000.0);
  });

  test('fromMap double balance', () {
    final b = WalletBalance.fromMap({'wallet_id': 'w2', 'balance': 10.5});
    expect(b.balance, 10.5);
  });

  test('fromMap string numeric balance', () {
    final b = WalletBalance.fromMap({'wallet_id': 'w3', 'balance': '2500'});
    expect(b.balance, 2500.0);
  });
}
```

- [ ] **Step 2: Commit test dulu (atau bareng implement di step 3 setelah push CI)**

Karena flutter tidak lokal, gabung test+implement dalam satu commit Task 2 (konvensi repo: pure unit, CI yang run).

- [ ] **Step 3: Implement model**

`lib/models/wallet_balance.dart`:

```dart
class WalletBalance {
  final String walletId;
  final double balance;
  const WalletBalance({required this.walletId, required this.balance});

  factory WalletBalance.fromMap(Map<String, dynamic> m) {
    final raw = m['balance'];
    final double bal;
    if (raw is num) {
      bal = raw.toDouble();
    } else if (raw is String) {
      bal = double.tryParse(raw) ?? 0;
    } else {
      bal = 0;
    }
    return WalletBalance(
      walletId: m['wallet_id'].toString(),
      balance: bal,
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/models/wallet_balance.dart test/wallet_balance_test.dart
git commit -m "feat: WalletBalance model + fromMap tests"
```

---

### Task 3: Helper `validateTxInput` + test

**Files:**
- Create: `lib/core/saas/tx_validation.dart`
- Test: `test/tx_validation_test.dart`

**Interfaces:**
- Consumes: tidak ada (pure).
- Produces:
  ```dart
  String? validateTxInput({
    required double amount,
    required String? walletId,
    required String type,
    String? toWalletId,
  });
  ```
  Return `null` = OK, atau pesan error Indonesia (tanpa em dash).
- Dipakai: Task 6 `_save`.

- [ ] **Step 1: Tulis test**

`test/tx_validation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/saas/tx_validation.dart';

void main() {
  test('amount <= 0 ditolak', () {
    expect(
      validateTxInput(amount: 0, walletId: 'w1', type: 'out'),
      'Nominal harus lebih dari 0',
    );
    expect(
      validateTxInput(amount: -5, walletId: 'w1', type: 'in'),
      'Nominal harus lebih dari 0',
    );
  });

  test('wallet wajib', () {
    expect(
      validateTxInput(amount: 1000, walletId: null, type: 'out'),
      'Pilih dompet',
    );
  });

  test('transfer tujuan null', () {
    expect(
      validateTxInput(amount: 1000, walletId: 'w1', type: 'transfer', toWalletId: null),
      'Pilih dompet tujuan',
    );
  });

  test('transfer tujuan sama dengan asal', () {
    expect(
      validateTxInput(amount: 1000, walletId: 'w1', type: 'transfer', toWalletId: 'w1'),
      'Dompet tujuan sama dengan asal',
    );
  });

  test('input valid', () {
    expect(
      validateTxInput(amount: 1000, walletId: 'w1', type: 'out'),
      isNull,
    );
    expect(
      validateTxInput(amount: 1000, walletId: 'w1', type: 'transfer', toWalletId: 'w2'),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Implement**

`lib/core/saas/tx_validation.dart`:

```dart
String? validateTxInput({
  required double amount,
  required String? walletId,
  required String type,
  String? toWalletId,
}) {
  if (amount <= 0) return 'Nominal harus lebih dari 0';
  if (walletId == null) return 'Pilih dompet';
  if (type == 'transfer') {
    if (toWalletId == null) return 'Pilih dompet tujuan';
    if (toWalletId == walletId) return 'Dompet tujuan sama dengan asal';
  }
  return null;
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/saas/tx_validation.dart test/tx_validation_test.dart
git commit -m "feat: validateTxInput helper + tests"
```

---

### Task 4: `TransactionService.update` + `delete`

**Files:**
- Modify: `lib/core/saas/transaction_service.dart` (setelah `add`, akhir class)

**Interfaces:**
- Consumes: `SupabaseConfig.client`, pola `.eq('org_id')` dari `list`.
- Produces:
  ```dart
  Future<void> update({
    required String id,
    required String orgId,
    required String type,
    required double amount,
    String? walletId,
    String? toWalletId,
    String? category,
    String? note,
    String? date,
  });

  Future<void> delete(String id, String orgId);
  ```
- Dipakai: Task 6.

- [ ] **Step 1: Tambah method `update` dan `delete`**

Di `transaction_service.dart`, setelah method `add` (setelah baris penutup `add`, sebelum `}` class), tambahkan:

```dart
  Future<void> update({
    required String id,
    required String orgId,
    required String type,
    required double amount,
    String? walletId,
    String? toWalletId,
    String? category,
    String? note,
    String? date,
  }) async {
    assert(amount > 0);
    await SupabaseConfig.client
        .from('transactions')
        .update({
          'type': type,
          'amount': amount,
          'wallet_id': walletId,
          'to_wallet_id': toWalletId,
          'category': category,
          'note': note,
          'date': date,
        })
        .eq('id', id)
        .eq('org_id', orgId);
  }

  Future<void> delete(String id, String orgId) async {
    await SupabaseConfig.client
        .from('transactions')
        .delete()
        .eq('id', id)
        .eq('org_id', orgId);
  }
```

Catatan: **tidak** update `code` / `source_*` / `created_*` / `org_id`.

- [ ] **Step 2: Commit**

```bash
git add lib/core/saas/transaction_service.dart
git commit -m "feat: transaction update + delete methods"
```

---

### Task 5: `WalletService.balances`

**Files:**
- Modify: `lib/core/saas/wallet_service.dart`
- Import: `lib/models/wallet_balance.dart`

**Interfaces:**
- Consumes: view `public.wallet_balance` (Task 1), model `WalletBalance` (Task 2).
- Produces: `Future<List<WalletBalance>> balances(String orgId)`
- Dipakai: Task 6 (dropdown), Task 7 (wallets screen).

- [ ] **Step 1: Implement**

`wallet_service.dart` — tambah import dan method:

```dart
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';

class WalletService {
  Future<List<Wallet>> list(String orgId) async {
    final rows = await SupabaseConfig.client.from('wallets').select().eq('org_id', orgId).order('created_at');
    return List<Map<String, dynamic>>.from(rows).map(Wallet.fromMap).toList();
  }

  Future<void> create(String orgId, String name, String type) async {
    await SupabaseConfig.client.from('wallets').insert({'org_id': orgId, 'name': name, 'type': type});
  }

  Future<List<WalletBalance>> balances(String orgId) async {
    final rows = await SupabaseConfig.client
        .from('wallet_balance')
        .select()
        .eq('org_id', orgId);
    return List<Map<String, dynamic>>.from(rows)
        .map(WalletBalance.fromMap)
        .toList();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/saas/wallet_service.dart
git commit -m "feat: WalletService.balances from wallet_balance view"
```

---

### Task 6: UI edit/hapus + dropdown saldo di `transactions_screen`

**Files:**
- Modify: `lib/screens/transactions_screen.dart`

**Interfaces:**
- Consumes:
  - `TransactionService.update` / `delete` (Task 4)
  - `validateTxInput` (Task 3)
  - `WalletService.balances` (Task 5)
  - `WalletBalance.walletId` / `.balance` (Task 2)
- Produces: perilaku UI (tidak dipakai task lain).

**Aturan UI (antislop):** tanpa em dash; banner edit = fokal; baris terpilih `selected: true`; tombol Hapus danger + dialog konfirmasi; empty state teks sebab+aksi; dropdown `nama · rp(balance)` warna sekunder.

- [ ] **Step 1: State + load balances**

Di `_TransactionsScreenState` tambah:

```dart
  SaasTransaction? editing;
  List<WalletBalance> balances = [];
  DateTime? editDate;
  final formKey = GlobalKey<FormState>();
```

Import tambahan:

```dart
import 'package:ssr_space/core/saas/tx_validation.dart';
import 'package:ssr_space/models/wallet_balance.dart';
```

Di `_load()`, setelah `final w = await WalletService().list(orgId);`:

```dart
      List<WalletBalance> bals = [];
      try {
        bals = await WalletService().balances(orgId);
      } catch (_) {
        bals = [];
      }
      final t = await TransactionService().listMonth(orgId, month);
      if (!mounted) return;
      setState(() {
        noOrg = false;
        wallets = w;
        balances = bals;
        items = t;
        loading = false;
      });
```

(Hapus setState lama yang hanya `wallets`/`items`; gabung di atas. Bila balances gagal, `balances = []` → dropdown nama saja, form tetap jalan.)

Helper lokal:

```dart
  double? _balanceOf(String? id) {
    if (id == null) return null;
    for (final b in balances) {
      if (b.walletId == id) return b.balance;
    }
    return null;
  }

  void _startEdit(SaasTransaction t) {
    setState(() {
      editing = t;
      type = t.type;
      amountC.text = t.amount.toStringAsFixed(0);
      catC.text = t.category ?? '';
      noteC.text = t.note ?? '';
      walletId = t.walletId;
      toWalletId = t.toWalletId;
      editDate = t.date == null ? null : DateTime.tryParse(t.date!);
      formErr = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        formKey.currentContext ?? context,
        duration: Duration.zero,
      );
    });
  }

  void _cancelEdit() {
    setState(() {
      editing = null;
      editDate = null;
      type = 'out';
      amountC.clear();
      noteC.clear();
      catC.clear();
      walletId = null;
      toWalletId = null;
      formErr = null;
    });
  }
```

- [ ] **Step 2: Ganti `_save` (validasi + add vs update)**

Ganti seluruh method `_save` dengan:

```dart
  Future<void> _save() async {
    final nominal = double.tryParse(amountC.text);
    if (nominal == null) {
      setState(() => formErr = 'Isi nominal dengan angka yang benar.');
      return;
    }
    final v = validateTxInput(
      amount: nominal,
      walletId: walletId,
      type: type,
      toWalletId: toWalletId,
    );
    if (v != null) {
      setState(() => formErr = v);
      return;
    }
    setState(() { saving = true; formErr = null; });
    try {
      final orgId = await _orgId();
      final cat = catC.text.trim().isEmpty ? null : catC.text.trim();
      final note = noteC.text.trim();
      final svc = TransactionService();
      if (editing != null) {
        await svc.update(
          id: editing!.id,
          orgId: orgId,
          type: type,
          amount: nominal,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note.isEmpty ? null : note,
          date: editDate == null
              ? editing!.date
              : '${editDate!.year.toString().padLeft(4, '0')}-'
                  '${editDate!.month.toString().padLeft(2, '0')}-'
                  '${editDate!.day.toString().padLeft(2, '0')}',
        );
        if (!mounted) return;
        _cancelEdit();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi diperbarui')),
        );
      } else {
        await svc.add(
          orgId: orgId,
          type: type,
          amount: nominal,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note,
        );
        if (!mounted) return;
        amountC.clear();
        noteC.clear();
        catC.clear();
        setState(() {
          walletId = null;
          toWalletId = null;
        });
      }
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => formErr = 'Gagal menyimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (editing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi'),
        content: const Text('Hapus transaksi ini? Tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || editing == null) return;
    try {
      final orgId = await _orgId();
      await TransactionService().delete(editing!.id, orgId);
      if (!mounted) return;
      _cancelEdit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi dihapus')),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => formErr = 'Gagal menghapus. Coba lagi.');
    }
  }
```

- [ ] **Step 3: Banner edit + label judul form + tombol**

Di `build`, judul form ganti:

```dart
        Text(
          editing != null ? 'Mengubah transaksi' : 'Catat transaksi',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (editing != null) ...[
          const SizedBox(height: 8),
          Container(
            key: formKey,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SsrColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mengubah ${editing!.code ?? 'transaksi'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: _cancelEdit,
                  child: const Text('Batalkan edit'),
                ),
              ],
            ),
          ),
        ],
```

(Taruh `key: formKey` di banner; bila `editing == null` pindahkan key ke judul atau gunakan `GlobalKey` pada widget form container lain. Alternatif aman: bungkus seluruh blok form dalam `Container(key: formKey, ...)` tanpa banner. Pilih: `key: formKey` pada `ListView` child pertama form yaitu banner bila edit, else pada `Text('Catat transaksi')` tidak perlu scroll. Praktis: `Scrollable.ensureVisible` context = `formKey.currentContext` yang dipasang pada banner saat edit; saat add tidak butuh.)

- [ ] **Step 4: Dropdown dompet + tujuan dengan subtitle saldo**

Ganti item dropdown dompet (dua tempat: `walletId` dan `toWalletId`):

```dart
          items: [
            for (final w in wallets)
              DropdownMenuItem(
                value: w.id,
                child: Text(
                  _balanceOf(w.id) == null
                      ? w.name
                      : '${w.name} · ${rp(_balanceOf(w.id)!)}',
                  style: _balanceOf(w.id) == null
                      ? null
                      : Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5F5E5B),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                ),
              ),
          ],
```

Import `dart:ui` untuk `FontFeature` bila perlu (`import 'dart:ui' show FontFeature;`).

- [ ] **Step 5: Area tombol simpan + hapus**

Ganti blok `saving ? ... : ElevatedButton(...)` dengan:

```dart
        const SizedBox(height: 12),
        if (saving)
          const Center(child: CircularProgressIndicator())
        else ...[
          ElevatedButton(
            onPressed: _save,
            child: Text(editing != null ? 'Simpan perubahan' : 'Simpan transaksi'),
          ),
          if (editing != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _confirmDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB3261E),
                  side: const BorderSide(color: Color(0xFFB3261E)),
                ),
                child: const Text('Hapus'),
              ),
            ),
          ],
        ],
```

- [ ] **Step 6: ListTile onTap + selected + empty state**

```dart
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Belum ada transaksi bulan ini. Catat pemasukan atau pengeluaran di form di atas.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        for (final t in items) ...[
          ListTile(
            selected: editing?.id == t.id,
            onTap: () => _startEdit(t),
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: SsrColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconForCategory(t.category), color: SsrColors.accent),
            ),
            title: Text(
              '${t.type == 'in' ? 'Masuk' : t.type == 'transfer' ? 'Transfer' : 'Keluar'}: ${rp(t.amount)}',
              style: SsrTheme.money,
            ),
            subtitle: Text(
              '${t.code ?? '-'}${t.sourcePackage != null ? ' | Otomatis' : ''} | ${t.category ?? '-'} ${t.note?.isNotEmpty ?? false ? '| ${t.note}' : ''}',
            ),
          ),
          const Divider(height: 1),
        ],
```

- [ ] **Step 7: Commit**

```bash
git add lib/screens/transactions_screen.dart
git commit -m "feat: edit delete transactions UI + balance in wallet dropdown"
```

---

### Task 7: Saldo di layar Dompet

**Files:**
- Modify: `lib/screens/wallets_screen.dart`

**Interfaces:**
- Consumes: `WalletService.balances` (Task 5), `rp` (`core/format/money.dart`), `SsrTheme.money`.
- Produces: tampilan saldo (UI only).

- [ ] **Step 1: State balances + load**

Import:

```dart
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/models/wallet_balance.dart';
```

State:

```dart
  List<WalletBalance> balances = [];
  bool balancesOk = false;
```

Di `_load` setelah `final data = await WalletService().list(orgId);`:

```dart
      List<WalletBalance> bals = [];
      var bOk = false;
      try {
        bals = await WalletService().balances(orgId);
        bOk = true;
      } catch (_) {
        bals = [];
        bOk = false;
      }
      if (!mounted) return;
      setState(() {
        noOrg = false;
        items = data;
        balances = bals;
        balancesOk = bOk;
        loading = false;
      });
```

(Hapus/Harmoniskan setState lama `items = data; loading = false`.)

Helper:

```dart
  String _balanceLabel(String walletId) {
    if (!balancesOk) return 'Belum termuat';
    for (final b in balances) {
      if (b.walletId == walletId) return rp(b.balance);
    }
    return rp(0);
  }
```

- [ ] **Step 2: ListTile trailing saldo**

```dart
        for (final w in items) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(w.name, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(w.type),
            trailing: Text(
              _balanceLabel(w.id),
              style: SsrTheme.money.copyWith(
                color: const Color(0xFF1C1B1A),
              ),
            ),
          ),
          const Divider(height: 1),
        ],
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/wallets_screen.dart
git commit -m "feat: show wallet balance on wallets screen"
```

---

### Task 8: Versi + AUDIT.md

**Files:**
- Modify: `pubspec.yaml` (baris `version:`)
- Modify: `AUDIT.md` (Sprint A A1/A2 + checklist §5)

**Interfaces:**
- Consumes: hasil Task 1-7.
- Produces: versi `2.3.4+16`; status backlog.

- [ ] **Step 1: pubspec**

```yaml
version: 2.3.4+16
```

- [ ] **Step 2: AUDIT.md**

Di §4 Sprint A, tandai:

| # | Item | Status |
|---|------|--------|
| A1 | Edit transaksi | ✅ done `2.3.4+16` (edit in-place + hapus) |
| A2 | Saldo dompet | ✅ done `2.3.4+16` (`migration_09` view) |

Tambah bullet checklist §5 (dari spec §6): migration_09, saldo per baris, edit ubah wallet, transfer ±, hapus konfirmasi, dropdown `nama · Rp`, “Belum termuat”, empty state, tanpa em dash.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml AUDIT.md
git commit -m "chore: version 2.3.4+16 + audit A1 A2 done"
```

---

### Task 9: Push, CI, APK, Delivery Gate

**Files:**
- Tidak ada source baru; push semua commit Task 1-8.

**Interfaces:**
- Consumes: semua task sebelumnya.
- Produces: artifact `ssr-space-apk`, file di `/sdcard/Download/SSR-SPACE/`, laporan Delivery Gate.

- [ ] **Step 1: Push**

```bash
git push origin main
```

- [ ] **Step 2: Pantau CI**

```bash
gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status
```

Expected: green (`flutter test` termasuk `wallet_balance_test` + `tx_validation_test`).

Bila merah: perbaiki sesuai log, commit `fix:`, push ulang, watch lagi.

- [ ] **Step 3: Download APK**

```bash
RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
mkdir -p /sdcard/Download/SSR-SPACE
gh run download "$RUN_ID" -n ssr-space-apk -D /sdcard/Download/SSR-SPACE/
```

- [ ] **Step 4: Delivery Gate antislop (spec §7) — isi PASS/FAIL**

Wajib cek (report di jawaban akhir, satu baris per item + bukti):

1. R-02: grep copy UI di file yang diubah, tidak ada `—`.
2. R-03: tidak ada layout overflow (code review Expanded/ListView); tombol Hapus height 48.
3. R-25: kontras danger 6.25 / sekunder 6.20 / zamrud 5.23 (sudah diukur di spek).
4. R-26: semua tombol (Batalkan edit, Hapus, Simpan, dialog) punya handler.
5. R-27: empty/loading/error transactions + wallets + “Belum termuat” balances.
6. R-37: Design Read spek dipakai.
7. R-31: tabel alasan spek §3.
8. Blok 3 liveliness: dials 1/2/1, fokal banner edit + saldo kanan, motif hairline.
9. CI green = R-35 sebagian (test jalan); checklist device = pelengkap user.

Bila ada FAIL: perbaiki dulu, jangan serah.

- [ ] **Step 5: Serah ke user**

Sebutkan:
- Path APK: `/sdcard/Download/SSR-SPACE/` (+ nama file artifact).
- **Wajib** jalankan `supabase/migration_09_wallet_balance.sql` di Supabase Dashboard.
- Delivery Gate report.
- Checklist device AUDIT §5 untuk verifikasi manual.

```bash
# tidak ada commit ekstra wajar; bila ada perbaikan gate:
# git add -A && git commit -m "fix: ..." && git push origin main
```

---

## Self-Review (plan vs spec)

1. **Spec coverage:** migration_09 (T1), WalletBalance (T2), validateTxInput (T4 spec §4 → T3), update/delete (T4), balances (T5), UI edit/banner/hapus/dropdown (T6), wallets saldo + “Belum termuat” (T7), versi+AUDIT (T8), delivery+gate (T9). Date edit via `editDate` + prefilled (T6). Empty state teks sebab+aksi (T6). ✅
2. **Placeholder:** tidak ada TBD/TODO; kode konkret di tiap step code. ✅
3. **Type consistency:** `WalletBalance.fromMap` / `validateTxInput` / `TransactionService.update|delete` / `WalletService.balances` nama sama di semua task. ✅
4. **Catatan:** test dijalankan di CI (bukan lokal Termux) — sudah digenapkan di Global Constraints.
