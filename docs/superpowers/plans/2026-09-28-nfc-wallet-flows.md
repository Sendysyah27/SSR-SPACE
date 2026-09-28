# NFC + Wallet Flows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verifikasi NFC 3-state, kartu→dompet dengan saldo-awal + tawar selisih, dan kelola dompet lengkap (rename/type/delete/saldo-awal).

**Architecture:** Service dulu (`WalletService` return-id + guard + hapus; pure validator + penyesuaian TDD), lalu UI dompet, lalu gate NFC, lalu flow taut kartu; rilis bump `2.4.12+46`. Tanpa migration, read-only selain insert yang disetujui user.

**Tech Stack:** Flutter stable, `flutter_nfc_kit: ^3.6.2` (baru, langsung), `prepaid_lib` (tetap), Supabase (RLS existing), prefs lokal.

**Spec:** `docs/superpowers/specs/2026-09-28-nfc-wallet-flows-design.md`

## Global Constraints

- `flutter analyze` 0 issue termasuk info (`prefer_const_*`, `avoid_print`→`debugPrint`, `use_build_context_synchronously`→`mounted`, `deprecated_member_use`, header file `//`).
- `flutter` tidak ada lokal; logika murni dicek `dart --enable-asserts` (wajib flag); suite penuh via CI.
- Local `git commit` per task diizinkan setelah plan disetujui; `git push` HANYA perintah eksplisit user.
- Copy UI hanya via `tr()` (kunci exact di bawah, ID+EN). Nominal via `amt()`. `build()` <50 baris.
- Tanpa migration. Tanpa `updateBalance`. Tanpa simpan nomor kartu penuh. Kategori `Saldo awal`/`Penyesuaian` TIDAK masuk 10 default.
- `flutter_nfc_kit: ^3.6.2` (API `FlutterNfcKit.nfcAvailability → NFCAvailability(not_supported|disabled|available)` terverifikasi docs 3.6.2).

---

### Task 1: Service dompet + validator murni + test

**Files:**
- Modify: `lib/services/wallet_service.dart` (create→id, +rename/changeType/hasTransactions/deleteWallet)
- Create: `lib/services/wallet_edit_logic.dart` (murni: `isValidWalletName`, `isKnownWalletType`)
- Create: `test/wallet_edit_test.dart`

**Interfaces:**
- Consumes: `SupabaseConfig.client`, `Wallet.fromMap` (ada).
- Produces (exact, dipakai Task 2/4):
  - `Future<String> create(String orgId, String name, String type)` (return id)
  - `Future<void> rename(String id, String orgId, String name)`
  - `Future<void> changeType(String id, String orgId, String type)`
  - `Future<bool> hasTransactions(String orgId, String walletId)`
  - `Future<void> deleteWallet(String id, String orgId)`
  - `bool isValidWalletName(String v)` → `v.trim().isNotEmpty`
  - `bool isKnownWalletType(String t)` → 5 tipe {cash, ewallet, bank, savings, investment}

- [ ] **Step 1: Tulis test validator yang gagal**

Create `test/wallet_edit_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/wallet_edit_logic.dart';

void main() {
  test('nama valid bila tak kosong', () {
    expect(isValidWalletName('Kas'), isTrue);
    expect(isValidWalletName('  DANA  '), isTrue);
    expect(isValidWalletName(''), isFalse);
    expect(isValidWalletName('   '), isFalse);
  });

  test('tipe dikenal hanya 5', () {
    for (final t in ['cash', 'ewallet', 'bank', 'savings', 'investment']) {
      expect(isKnownWalletType(t), isTrue);
    }
    expect(isKnownWalletType('crypto'), isFalse);
    expect(isKnownWalletType(''), isFalse);
  });
}
```

- [ ] **Step 2: Tulis file murni + ubah service**

Create `lib/services/wallet_edit_logic.dart`:
```dart
// Validasi edit dompet (murni, test lokal via dart --enable-asserts).
bool isValidWalletName(String v) => v.trim().isNotEmpty;

const _kWalletTypes = {'cash', 'ewallet', 'bank', 'savings', 'investment'};

bool isKnownWalletType(String t) => _kWalletTypes.contains(t);
```

Edit `lib/services/wallet_service.dart` (tambah import `supabase_config` sudah ada; file kini):
```dart
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';

class WalletService {
  Future<List<Wallet>> list(String orgId) async {
    final rows = await SupabaseConfig.client.from('wallets').select().eq('org_id', orgId).order('created_at');
    return List<Map<String, dynamic>>.from(rows).map(Wallet.fromMap).toList();
  }

  Future<String> create(String orgId, String name, String type) async {
    final row = await SupabaseConfig.client
        .from('wallets')
        .insert({'org_id': orgId, 'name': name, 'type': type})
        .select('id')
        .single();
    return row['id'].toString();
  }

  Future<void> rename(String id, String orgId, String name) async {
    await SupabaseConfig.client
        .from('wallets')
        .update({'name': name})
        .eq('id', id)
        .eq('org_id', orgId);
  }

  Future<void> changeType(String id, String orgId, String type) async {
    await SupabaseConfig.client
        .from('wallets')
        .update({'type': type})
        .eq('id', id)
        .eq('org_id', orgId);
  }

  Future<bool> hasTransactions(String orgId, String walletId) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select('id')
        .eq('org_id', orgId)
        .or('wallet_id.eq.$walletId,to_wallet_id.eq.$walletId')
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<void> deleteWallet(String id, String orgId) async {
    await SupabaseConfig.client
        .from('wallets')
        .delete()
        .eq('id', id)
        .eq('org_id', orgId);
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
CATATAN: pemanggil lama `wallets_screen.dart:156` (`await WalletService().create(orgId, name, type);`) tetap kompilasi (return diabaikan) — JANGAN ubah baris itu di task ini.

- [ ] **Step 3: Verifikasi lokal** — harness `/tmp` mirror 2 test via `dart --enable-asserts`. Expected PASS. Service methods (butuh Supabase) = CI + smoke.
- [ ] **Step 4: Commit** — `git add lib/services/wallet_service.dart lib/services/wallet_edit_logic.dart test/wallet_edit_test.dart && git commit -m "feat(wallet): service rename/type/hapus + validator murni"`. NO push.

### Task 2: UI kelola dompet + strings

**Files:**
- Modify: `lib/screens/dompet/wallet_detail_screen.dart` (aksi edit + danger hapus)
- Modify: `lib/screens/dompet/wallets_screen.dart` (field saldo-awal di form)
- Modify: `lib/utils/strings.dart` (blok baru)

**Interfaces:**
- Consumes Task 1: `rename`, `changeType`, `hasTransactions`, `deleteWallet`, `create` (return id), `isValidWalletName`, `isKnownWalletType`; `askPinDialog` (`widgets/pin_dialog.dart`); `TransactionService().add` (ada).
- Produces: detail me-refresh setelah edit (pola di bawah); tak ada API baru.

- [ ] **Step 1: Strings** — tambah sebelum `};` penutup `_t`:
```dart
  // Dompet: kelola
  'w_rename_t': {'id': 'Ubah dompet', 'en': 'Edit wallet'},
  'w_has_tx': {
    'id': 'Dompet berisi transaksi — hapus tidak bisa. Ubah nama bila perlu.',
    'en': 'Wallet has transactions — cannot delete. Rename if needed.',
  },
  'w_deleted': {'id': 'Dompet dihapus', 'en': 'Wallet deleted'},
  'w_del_confirm': {
    'id': 'Hapus dompet ini? Tindakan tak bisa dibatalkan.',
    'en': 'Delete this wallet? Cannot be undone.',
  },
  'w_opening': {'id': 'Saldo awal (opsional)', 'en': 'Opening balance (optional)'},
  'w_renamed': {'id': 'Dompet diperbarui', 'en': 'Wallet updated'},
```

- [ ] **Step 2: Dialog edit di detail** — di `_WalletDetailScreenState`: AppBar tambah `actions: [IconButton(icon: DuoIcon(AppIcons.settings), onPressed: _edit)]` (cek `AppIcons.settings` ada; bila tidak, pakai `AppIcons.menu`). `_edit()`:
```dart
  Future<void> _edit() async {
    final nameC = TextEditingController(text: widget.wallet.name);
    var type = widget.wallet.type;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('w_rename_t')),
          content: StatefulBuilder(
            builder: (ctx, setD) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameC,
                  decoration: InputDecoration(labelText: tr('w_f_name')),
                ),
                const SizedBox(height: SsrSpace.md),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: tr('w_f_type')),
                  items: [
                    for (final t in ['cash', 'ewallet', 'bank', 'savings', 'investment'])
                      DropdownMenuItem(value: t, child: Text(_typeLabel(t))),
                  ],
                  onChanged: (v) => setD(() => type = v ?? type),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('save')),
            ),
          ],
        ),
      );
      if (saved != true || !mounted) return;
      final name = nameC.text.trim();
      if (!isValidWalletName(nameC.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('w_err_name'))),
        );
        return;
      }
      final orgId = await activeOrgId();
      final svc = WalletService();
      if (name != widget.wallet.name) await svc.rename(widget.wallet.id, orgId, name);
      if (isKnownWalletType(type) && type != widget.wallet.type) {
        await svc.changeType(widget.wallet.id, orgId, type);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('w_renamed'))),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('w_err_save'))),
      );
    } finally {
      nameC.dispose();
    }
  }
```
`_typeLabel` di detail: duplikasi switch 5 tipe dari wallets_screen (kecil, mapan) — ATAU teruskan via ctor? Detail tidak terima callback. Duplikasi switch 10 baris diterima (pola repo: copy kecil > plumbing). Import yang perlu: `wallet_service.dart`, `wallet_edit_logic.dart`, `askPinDialog` (Step 3), `activeOrgId` (sudah), `AppIcons` (sudah). Pemanggil list (`_WalletListCard` onTap push detail) HARUS `await Navigator.push` + reload? Detail pop(true) → daftar reload: ubah onTap di wallets_screen jadi `async { final r = await Navigator.push(...); if (r == true && context.mounted) _reloadOnly(); }` — butuh akses `_load` dari `_WalletListCard` (stateless, terima callback `onChanged`). Tambah param `Future<void> Function() onChanged` ke `_WalletListCard`, teruskan dari state: `onChanged: _load` — CATATAN: `_load` set loading=true (skeleton kedip); diterima (pola reload existing).

- [ ] **Step 3: Danger hapus di detail** — bawah `ListView` detail tambah:
```dart
        const SizedBox(height: SsrSpace.lg),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _remove,
                child: Text(tr('tx_delete')),
              ),
            ],
          ),
        ),
```
`_remove()`:
```dart
  Future<void> _remove() async {
    final pinOk = await askPinDialog(context);
    if (!pinOk || !mounted) return;
    try {
      final orgId = await activeOrgId();
      final svc = WalletService();
      if (await svc.hasTransactions(orgId, widget.wallet.id)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('w_has_tx'))),
        );
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('w_del_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('tx_delete')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      try {
        await svc.deleteWallet(widget.wallet.id, orgId);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('w_has_tx'))),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('w_deleted'))),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('w_err_save'))),
      );
    }
  }
```
Cek `tr('tx_delete')` ada (dipakai other_screen clearCache ✓).

- [ ] **Step 4: Saldo awal di form baru** — `_NewWalletForm` tambah `TextEditingController openC` (state buat + dispose) + field:
```dart
          TextField(
            controller: openC,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('w_opening')),
          ),
```
`_save()`: setelah `create` KINI return id:
```dart
      final orgId = await activeOrgId();
      final id = await WalletService().create(orgId, name, type);
      final opening =
          int.tryParse(openC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (opening > 0) {
        try {
          await TransactionService().add(
            orgId: orgId,
            type: 'in',
            amount: opening.toDouble(),
            walletId: id,
            category: 'Saldo awal',
            note: 'Saldo awal $name',
            date: ymd(DateTime.now()),
          );
        } catch (_) {
          try {
            await WalletService().deleteWallet(id, orgId);
          } catch (_) {}
          await _load();
          if (!mounted) return;
          setState(() => formErr = tr('w_err_save'));
          return;
        }
      }
      openC.clear();
      nameC.clear();
```
Import `transaction_service.dart` + `datetime.dart` (cek nama fungsi ymd: `lib/utils/datetime.dart` — baca dulu, gunakan apa adanya; bila beda nama, pakai yang ada). `ymd` dipakai notif pipeline (`date: ymd(at)`) — ada.
- [ ] **Step 5: Commit** — `git add` 3 file + `git commit -m "feat(wallet): rename/type/hapus + saldo awal umum"`. NO push.

### Task 3: Gate NFC 3-state + strings

**Files:**
- Modify: `pubspec.yaml` (+`flutter_nfc_kit: ^3.6.2`)
- Modify: `lib/screens/lainnya/nfc_cards_screen.dart` (state + banner)
- Modify: `lib/utils/strings.dart`

**Interfaces:** consumes `FlutterNfcKit.nfcAvailability`; produces tak ada (UI internal).

- [ ] **Step 1: Dep** — tambah di pubspec (di bawah prepaid, komentar `# NFC gate: cek dukungan/switch`).
- [ ] **Step 2: Strings**:
```dart
  // NFC: gate ketersediaan
  'nfc_no_hw': {
    'id': 'HP ini tidak mendukung pembacaan NFC.',
    'en': 'This phone cannot read NFC.',
  },
  'nfc_off': {'id': 'NFC mati', 'en': 'NFC is off'},
  'nfc_off_steps': {
    'id': 'Nyalakan NFC di Pengaturan → Koneksi, lalu Coba lagi.',
    'en': 'Turn on NFC in Settings → Connections, then Retry.',
  },
  'nfc_retry': {'id': 'Coba lagi', 'en': 'Retry'},
```
- [ ] **Step 3: State + UI** — import `package:flutter_nfc_kit/flutter_nfc_kit.dart`; field `NFCAvailability? nfcAv;` di `_load()`: 
```dart
    try {
      nfcAv = await FlutterNfcKit.nfcAvailability;
    } catch (e) {
      debugPrint('nfc avail: $e');
      nfcAv = null;
    }
```
(set sebelum/bersama setState existing; `null` = tanpa gate). Di `build` ListView: `if (nfcAv == NFCAvailability.not_supported) _NoNfcCard() else _ScanCard(...)`; banner bila `disabled`: SectionCard(`tr('nfc_off')` + `tr('nfc_off_steps')` + OutlinedButton `tr('nfc_retry')` → `_load()`) + `_ScanCard` tetap tampil (biarkan coba, error jujur dari read). `_NoNfcCard`: SectionCard Text(`tr('nfc_no_hw')`).
- [ ] **Step 4: Commit** — `git commit -m "feat(nfc): gate ketersediaan 3-state"`. NO push.

### Task 4: Taut kartu→dompet + tawar selisih

**Files:**
- Modify: `lib/services/nfc_emoney_logic.dart` (+`nfcAdjustmentFor`)
- Modify: `test/nfc_emoney_test.dart` (+2 test)
- Modify: `lib/services/nfc_emoney.dart` (+`linkCardAsWallet`)
- Modify: `lib/screens/lainnya/nfc_cards_screen.dart` (tombol Jadikan dompet + sheet selisih)
- Modify: `lib/utils/strings.dart`

**Interfaces:**
- Produces: `({String type, double amount})? nfcAdjustmentFor({required double book, required int card})` (null bila sama/negatif)
- Produces: `Future<String> linkCardAsWallet({required String orgId, required String bank, required String last4, required int balance, required String label})`

- [ ] **Step 1: Logika + test penyesuaian** — append logic:
```dart
/// Selisih kartu vs buku: null bila cocok. card>book = in (top-up luar
/// buku), card<book = out (belanja luar buku). Negatif = invalid → null.
({String type, double amount})? nfcAdjustmentFor({
  required double book,
  required int card,
}) {
  if (book < 0 || card < 0) return null;
  final diff = card - book;
  if (diff == 0) return null;
  if (diff > 0) return (type: 'in', amount: diff);
  return (type: 'out', amount: -diff);
}
```
Test (dalam `main()`):
```dart
  test('selisih dua arah + cocok', () {
    expect(nfcAdjustmentFor(book: 9100, card: 100)!.type, 'out');
    expect(nfcAdjustmentFor(book: 9100, card: 100)!.amount, 9000);
    expect(nfcAdjustmentFor(book: 100, card: 50000)!.type, 'in');
    expect(nfcAdjustmentFor(book: 100, card: 50000)!.amount, 49900);
    expect(nfcAdjustmentFor(book: 100, card: 100), isNull);
    expect(nfcAdjustmentFor(book: -1, card: 100), isNull);
  });
```
Verifikasi lokal `dart --enable-asserts` harness.
- [ ] **Step 2: `linkCardAsWallet`** — append ke `nfc_emoney.dart` (import `wallet_service.dart`, `transaction_service.dart`, helper ymd dari `utils/datetime.dart` — baca nama exact dulu):
```dart
/// Kartu → dompet baru + saldo awal + taut. Gagal tengah = rollback
/// (hapus wallet fresh + buang kiriman gagal). Saldo 0 = dompet kosong.
Future<String> linkCardAsWallet({
  required String orgId,
  required String bank,
  required String last4,
  required int balance,
  required String label,
}) async {
  final walletId =
      await WalletService().create(orgId, '$bank •• $last4', 'ewallet');
  try {
    final all = await loadNfcCards();
    all.removeWhere((c) => c.uid == label);
    all.insert(
      0,
      NfcCard(
        uid: label,
        bank: bank,
        last4: last4,
        label: '$bank •• $last4',
        walletId: walletId,
        addedAt: DateTime.now().toIso8601String(),
      ),
    );
    await saveNfcCards(all);
    if (balance > 0) {
      final now = DateTime.now();
      await TransactionService().add(
        orgId: orgId,
        type: 'in',
        amount: balance.toDouble(),
        walletId: walletId,
        category: 'Saldo awal',
        note: 'Saldo awal $bank •• $last4 via NFC',
        date: ymd(now),
      );
      await addNfcCheck(NfcCheck(
        uid: label,
        bank: bank,
        balance: balance,
        at: now.toIso8601String(),
      ));
    }
    return walletId;
  } catch (e) {
    try {
      await WalletService().deleteWallet(walletId, orgId);
    } catch (_) {}
    final all = await loadNfcCards();
    all.removeWhere((c) => c.uid == label);
    await saveNfcCards(all);
    rethrow;
  }
}
```
CATATAN: parameter bernama `label` di sini = UID kartu (penanda stabil); JANGAN rename (pemanggil Task-langkah-3 pakai `uid:`? — TIDAK: signature exact di atas, pemanggil pakai `label: read.uid`). Hmm — nama parameter `label` untuk UID membingungkan. GANTI signature: `required String uid` + pakai `uid` di badan (3 titik: removeWhere, NfcCard, NfcCheck). Eksekutor: tulis versi `uid`, ABAIKAN blok di atas untuk nama itu (isi lain identik).
- [ ] **Step 3: UI taut + tawar** — strings:
```dart
  // NFC: taut dompet
  'nfc_make_wallet': {'id': 'Jadikan dompet', 'en': 'Make wallet'},
  'nfc_wallet_made': {
    'id': 'Dompet dibuat + saldo awal tercatat',
    'en': 'Wallet created with opening balance',
  },
  'nfc_matched': {'id': 'Sudah cocok dengan buku', 'en': 'Matches the books'},
  'nfc_diff': {'id': 'Selisih {m}', 'en': 'Difference {m}'},
```
`_ResultSheet` tambah param `required String? linkedWalletId` + `required Future<void> Function() onMade`: bila null → FilledButton `tr('nfc_make_wallet')` → 
```dart
    Future<void> _make() async {
      setState(() => busy = true);
      try {
        final orgId = await activeOrgId();
        await linkCardAsWallet(
          orgId: orgId,
          bank: widget.read.bank,
          last4: _last4(widget.read.number),
          balance: widget.read.balance ?? 0,
          uid: widget.read.uid,
        );
        await widget.onMade();
        if (!mounted) return;
        Navigator.pop(context);
      } catch (_) {
        if (!mounted) return;
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('nfc_read_fail'))),
        );
      }
    }
```
(`_last4`: helper lokal `String _last4(String n) { final t = n.trim(); return t.length >= 4 ? t.substring(t.length - 4) : ''; }`; `busy` state + `activeOrgId` import dari `org_prefs.dart` — cek nama: wallets_screen pakai `activeOrgId()` dari `utils/org_prefs.dart` ✓). Pemanggil `_scan`: teruskan `linkedWalletId: _linkedId(read.uid)` (cari di `cards`: `for (final c in cards) if (c.uid == uid) return c.walletId;` → helper `_linkedId`) + `onMade: () async { await _load(); if (mounted) ScaffoldMessenger...showSnackBar(Text(tr('nfc_wallet_made'))); }` — CATATAN: snackbar + pop ganda (sheet pop di _make + ...) — urutan: onMade (load+snack di screen di bawah sheet — snackbar tertutup sheet; PINDAH snack ke _make setelah pop? Sederhanakan: onMade HANYA `_load()`; snack `nfc_wallet_made` di `_make` setelah `Navigator.pop`. Tulis begitu.)
  Tawar selisih: di `_scan`, BILA kartu tertaut (`wid != null`) dan `read.ok` dan `read.balance != null`: ambil buku via `WalletService().balances(orgId)` → cari id → `book`; `nfcAdjustmentFor(book: book, card: read.balance!)`; null → show sheet hasil normal + snack `nfc_matched`? (snack di atas sheet tak terlihat — tampilkan teks cocok DI sheet: teruskan `matched: true` ke `_ResultSheet` → banner kecil `tr('nfc_matched')`); non-null → `_AdjustSheet(read, offer, book)` (widget baru file sama): teks `tr('nfc_diff').replaceFirst('{m}', amt(...))` + arah + tombol `rb_record` → `add(type: offer.type, amount: offer.amount, walletId: wid, category: 'Penyesuaian', note: 'Penyesuaian NFC {bank} •• {last4}', date: today)` + pop + reload + snack `tx_updated` (reuse, ada ✓) / `rb_skip` → pop. Dompet hilang dari balances → buang taut (`removeWhere uid` + save) + sheet normal.
- [ ] **Step 4: Commit** — semua file + `git commit -m "feat(nfc): taut kartu-dompet + tawar selisih"`. NO push.

### Task 5: Rilis 2.4.12+46

**Files:** `pubspec.yaml`, `lib/utils/app_info.dart`, `assets/changelog_id.md`, `AGENTS.md`, `AUDIT.md`.

- [ ] **Step 1: Bump** — `2.4.11+45` → `2.4.12+46` di ketiga (changelog: `Versi terpasang: 2.4.12+46.` + seksi):
```markdown
## Yang baru di 2.4.12

1. E-Money NFC terverifikasi: peringatan jujur bila HP tak mendukung atau NFC mati, tombol Coba lagi.
2. Kartu bisa dijadikan dompet: saldo awal tercatat sebagai transaksi, tap berikutnya menawar catat selisih atau lewati.
3. Kelola dompet lengkap: ubah nama dan jenis, hapus (kunci PIN, hanya bila kosong), saldo awal untuk dompet baru.
```
- [ ] **Step 2: Docs lokal** — AGENTS.md bullet:
```
- **NFC + dompet lengkap (2026-09-28, run CI berikut):** gate NFC 3-state (`flutter_nfc_kit ^3.6.2`); kartu→dompet (saldo-awal + tawar selisih dua arah, kategori `Saldo awal`/`Penyesuaian`, rollback); rename/type tanpa PIN, hapus PIN + kosong saja (FK backstop), saldo-awal umum. Tanpa migration. Bump `2.4.12+46`. APK `SSR-SPACE-2.4.12-46-nfc-dompet-arm64.apk`.
```
AUDIT.md §7 row:
```
| (nfc-dompet, run CI berikut) | **Gate NFC + kartu→dompet + kelola dompet (2.4.12+46):** A: dep langsung + banner 3-state; B: `linkCardAsWallet` (create→taut→opening, rollback) + `nfcAdjustmentFor` murni TDD + sheet Catat/Lewati; C: `WalletService` return-id/rename/type/hasTransactions/delete + edit dialog + hapus PIN + saldo-awal form. Tanpa migration. Batas sadar: Flazz dkk best-effort; opening menaikkan pemasukan (by design). APK `SSR-SPACE-2.4.12-46-nfc-dompet-arm64.apk`. |
```
- [ ] **Step 3: Commit** — `git commit -m "feat: rilis NFC-dompet 2.4.12+46"`. STOP — push + CI + APK = gate user terpisah.

## Self-Review

1. **Spec coverage:** §1 dep+states→T3; §2.1 urutan/rollback/note/kategori→T4S2 (plus saldo-0 rule tambahan — konsisten, menutup lubang `assert(amount>0)`); §2.2 math/kategori/note/sheet→T4S1+S3 (+matched-banner, wallet-gone); §3.1 lima signature→T1S2 (+callers kompatibel); §3.2 dialog/PIN/guard/form→T2S2-S4; §3.3 4 lapis→T2S3; §4 strings (semua kunci ada nilai exact; `nfc_diff` placeholder `{m}` konsisten dgn `replaceFirst`); version/changelog/APK→T5; build order→urutan task. Tanpa gap.
2. **Placeholder scan:** tanpa TBD/TODO/"nanti"; semua kode tampil penuh; satu instruksi "baca dulu" (ymd, AppIcons.settings fallback) dengan fallback exact bila absen.
3. **Type consistency:** `create` return `String` dipakai T2S4 (`final id`), T4S2 (`walletId`), T4S3 (`linkCardAsWallet` return) ✓; `nfcAdjustmentFor` record `{type,amount}` dipakai sheet (`offer.type/offer.amount`) ✓; `hasTransactions(orgId, walletId)` dipakai `_remove` ✓; `linkCardAsWallet` param `uid` (per CATATAN Step 2, bukan `label`) dipakai `_make` (`uid: widget.read.uid`) ✓; `NfcCard(uid,bank,last4,label,walletId,addedAt)` + `NfcCheck(uid,bank,balance,at)` sesuai Task-1 ✓.
