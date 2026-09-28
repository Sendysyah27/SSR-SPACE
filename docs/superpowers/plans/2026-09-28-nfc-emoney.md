# NFC E-Money Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Baca saldo e-money via NFC (Mandiri terbukti device, lainnya best-effort) + taut kartu ke dompet + histori cek lokal, read-only, tanpa migration.

**Architecture:** Logika murni (`nfc_emoney_logic.dart`, tanpa import Flutter) diuji TDD; wrapper tipis (`nfc_emoney.dart`) untuk init/read/prefs; satu layar hub (`nfc_cards_screen.dart`); layar spike dihapus; patch native CI dipertahankan dengan relabel.

**Tech Stack:** Flutter stable, `prepaid_lib_flutter_null_safety: ^1.0.1` (dipin exact), SharedPreferences, CI (`flutter analyze` 0 issue + `flutter test` + APK).

**Spec:** `docs/superpowers/specs/2026-09-28-nfc-emoney-design.md`

## Global Constraints

- `flutter analyze` wajib 0 issue termasuk level info (`prefer_const_constructors`, `avoid_print`→`debugPrint`, `use_build_context_synchronously`→`mounted` guard, komentar file pakai `//` bukan `///` di baris atas).
- `flutter` tidak ada lokal; file murni-Dart dicek via `dart --enable-asserts`, suite penuh via CI.
- Local `git commit` per task diizinkan setelah plan ini disetujui user; `git push` HANYA atas perintah eksplisit user.
- Copy UI hanya lewat `lib/utils/strings.dart` (kunci `nfc_*`, ID+EN).
- Nominal uang lewat `amt()`/`rp()`; jangan tambah `fontFamily` hardcoded.
- Tanpa migration, tanpa top-up (`updateBalance` dilarang muncul di kode mana pun), tanpa simpan nomor kartu penuh.

---

### Task 1: Logika murni + unit test (TDD)

**Files:**
- Create: `lib/services/nfc_emoney_logic.dart`
- Create: `test/nfc_emoney_test.dart`

**Interfaces:**
- Consumes: nothing (pure Dart, `dart:convert` only).
- Produces (used by Task 2 & 3, exact signatures):
  - `enum NfcEntryDir { credit, debit, unknown }`
  - `class NfcCardEntry { final int amount; final int balance; final int counter; final String date; final String tid; final String type; final NfcEntryDir dir; const NfcCardEntry({required this.amount, required this.balance, required this.counter, required this.date, required this.tid, required this.type, required this.dir}); }`
  - `NfcEntryDir nfcDirOf(String type)` — `'1'`→credit, `'2001'`→debit, else unknown.
  - `int? parseNfcBalance(String raw)` — `int.tryParse` setelah trim; gagal→null.
  - `List<NfcCardEntry> parseNfcHistory(String raw)` — decode JSON list, baris rusak dilewati, sort `counter` desc.
  - `String nfcBankLabel(String bank)` — trim+uppercase, kosong→`'UNKNOWN'`.
  - `String maskCardNumber(String number)` — `>=8` digit→`'6032 •••• 3976'`, kosong→`'-'`, pendek→apa adanya.
  - `class NfcCard { final String uid; final String bank; final String last4; final String label; final String? walletId; final String addedAt; const NfcCard(...); Map<String,dynamic> toJson(); static NfcCard? tryParse(dynamic raw); }` — tolak bila `uid` kosong.
  - `class NfcCheck { final String uid; final String bank; final int balance; final String at; const NfcCheck(...); Map<String,dynamic> toJson(); static NfcCheck? tryParse(dynamic raw); }` — tolak bila `uid` kosong / balance null / `at` bukan tanggal.
  - `const maxNfcCards = 20; const maxNfcChecks = 50;`
  - `List<T> capList<T>(List<T> all, int max)`

- [ ] **Step 1: Tulis test yang gagal**

Create `test/nfc_emoney_test.dart` (Sampel = data spike asli, nomor disamarkan):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/nfc_emoney_logic.dart';

const _hist = '[{"amount":"9000","balance":"100","counter":"15","date":"2026-8-28 20:24:16","no":"1","tid":"72100851","type":"2001"},{"amount":"100000","balance":"151000","counter":"6","date":"2019-8-4 8:44:40","no":"8","tid":"43061933","type":"1"},{"amount":"x","balance":"0","counter":"99","date":"bad","no":"9","tid":"","type":"2001"}]';

void main() {
  test('saldo valid vs gagal', () {
    expect(parseNfcBalance('100'), 100);
    expect(parseNfcBalance('  45500 '), 45500);
    expect(parseNfcBalance(''), isNull);
    expect(parseNfcBalance('abc'), isNull);
  });

  test('histori sort counter desc + peta tipe + baris rusak dibuang', () {
    final out = parseNfcHistory(_hist);
    expect(out.length, 2);
    expect(out[0].counter, 15);
    expect(out[0].dir, NfcEntryDir.debit);
    expect(out[0].balance, 100);
    expect(out[1].counter, 6);
    expect(out[1].dir, NfcEntryDir.credit);
    expect(parseNfcHistory('bukan json'), isEmpty);
    expect(parseNfcHistory('[]'), isEmpty);
  });

  test('label bank + masker nomor', () {
    expect(nfcBankLabel(' mandiri '), 'MANDIRI');
    expect(nfcBankLabel(''), 'UNKNOWN');
    expect(maskCardNumber('6032986072713976'), '6032 •••• 3976');
    expect(maskCardNumber('123'), '123');
    expect(maskCardNumber(''), '-');
  });

  test('NfcCard round-trip + tolak uid kosong', () {
    final c = NfcCard(
      uid: 'CFEF1CCD',
      bank: 'MANDIRI',
      last4: '3976',
      label: 'Mandiri •• 3976',
      walletId: null,
      addedAt: '2026-09-28T00:00:00.000',
    );
    final back = NfcCard.tryParse(c.toJson())!;
    expect(back.uid, 'CFEF1CCD');
    expect(back.walletId, isNull);
    expect(NfcCard.tryParse({'uid': ''}), isNull);
    expect(NfcCard.tryParse('x'), isNull);
  });

  test('NfcCheck tolak bentuk rusak', () {
    expect(
      NfcCheck.tryParse({
        'uid': 'CFEF1CCD',
        'bank': 'MANDIRI',
        'balance': 100,
        'at': '2026-09-28T00:00:00.000',
      })!.balance,
      100,
    );
    expect(NfcCheck.tryParse({'uid': 'A'}), isNull);
  });

  test('capList memotong di max', () {
    expect(capList([1, 2, 3], 20), [1, 2, 3]);
    expect(capList([for (var i = 0; i < 60; i++) i], 50).length, 50);
  });
}
```

- [ ] **Step 2: Tulis implementasi minimal**

Create `lib/services/nfc_emoney_logic.dart` (header komentar pakai `//`, import `dart:convert` saja):

```dart
// Baca saldo e-money: parse murni hasil getCardInfo/getHistory.
// Tanpa import Flutter — cek lokal via dart --enable-asserts.
import 'dart:convert';

enum NfcEntryDir { credit, debit, unknown }

NfcEntryDir nfcDirOf(String type) => switch (type) {
      '1' => NfcEntryDir.credit,
      '2001' => NfcEntryDir.debit,
      _ => NfcEntryDir.unknown,
    };

int? parseNfcBalance(String raw) => int.tryParse(raw.trim());

String nfcBankLabel(String bank) {
  final b = bank.trim();
  if (b.isEmpty) return 'UNKNOWN';
  return b.toUpperCase();
}

String maskCardNumber(String number) {
  final n = number.trim();
  if (n.isEmpty) return '-';
  if (n.length < 8) return n;
  return '${n.substring(0, 4)} •••• ${n.substring(n.length - 4)}';
}

class NfcCardEntry {
  final int amount;
  final int balance;
  final int counter;
  final String date;
  final String tid;
  final String type;
  final NfcEntryDir dir;
  const NfcCardEntry({
    required this.amount,
    required this.balance,
    required this.counter,
    required this.date,
    required this.tid,
    required this.type,
    required this.dir,
  });
}

List<NfcCardEntry> parseNfcHistory(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    final out = <NfcCardEntry>[];
    for (final e in decoded) {
      if (e is! Map) continue;
      final amount = (e['amount'] as num?)?.toInt();
      final balance = (e['balance'] as num?)?.toInt();
      final counter = (e['counter'] as num?)?.toInt();
      final date = e['date']?.toString() ?? '';
      final tid = e['tid']?.toString() ?? '';
      final type = e['type']?.toString() ?? '';
      if (amount == null || balance == null || counter == null) continue;
      out.add(NfcCardEntry(
        amount: amount,
        balance: balance,
        counter: counter,
        date: date,
        tid: tid,
        type: type,
        dir: nfcDirOf(type),
      ));
    }
    out.sort((a, b) => b.counter.compareTo(a.counter));
    return out;
  } catch (_) {
    return [];
  }
}

class NfcCard {
  final String uid;
  final String bank;
  final String last4;
  final String label;
  final String? walletId;
  final String addedAt;
  const NfcCard({
    required this.uid,
    required this.bank,
    required this.last4,
    required this.label,
    required this.walletId,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'bank': bank,
        'last4': last4,
        'label': label,
        'walletId': walletId,
        'addedAt': addedAt,
      };

  static NfcCard? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final uid = raw['uid']?.toString() ?? '';
    if (uid.isEmpty) return null;
    return NfcCard(
      uid: uid,
      bank: raw['bank']?.toString() ?? 'UNKNOWN',
      last4: raw['last4']?.toString() ?? '',
      label: raw['label']?.toString() ?? uid,
      walletId: raw['walletId']?.toString(),
      addedAt: raw['addedAt']?.toString() ?? '',
    );
  }
}

class NfcCheck {
  final String uid;
  final String bank;
  final int balance;
  final String at;
  const NfcCheck({
    required this.uid,
    required this.bank,
    required this.balance,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'bank': bank,
        'balance': balance,
        'at': at,
      };

  static NfcCheck? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final uid = raw['uid']?.toString() ?? '';
    final balance = (raw['balance'] as num?)?.toInt();
    final at = raw['at']?.toString() ?? '';
    if (uid.isEmpty || balance == null || DateTime.tryParse(at) == null) {
      return null;
    }
    return NfcCheck(
      uid: uid,
      bank: raw['bank']?.toString() ?? 'UNKNOWN',
      balance: balance,
      at: at,
    );
  }
}

const maxNfcCards = 20;
const maxNfcChecks = 50;

List<T> capList<T>(List<T> all, int max) =>
    all.length <= max ? List<T>.of(all) : all.sublist(0, max);
```

- [ ] **Step 3: Verifikasi lokal (tanpa flutter)**

Run: `dart --enable-asserts` pada harness scratch di `/tmp` (jangan di-commit) yang mengimpor file logic dan menjalankan 7 ekspektasi di atas. Expected: 7/7 PASS. (Pola repo: verifikasi logika murni lokal sebelum CI; `dart` tanpa flag memberi PASS palsu.)

- [ ] **Step 4: Commit lokal**

```bash
git add lib/services/nfc_emoney_logic.dart test/nfc_emoney_test.dart
git commit -m "feat(nfc): logika murni parse e-money + test (TDD)"
```

### Task 2: Service wrapper (init/read/prefs)

**Files:**
- Create: `lib/services/nfc_emoney.dart`
- Modify: `test/nfc_emoney_test.dart` (tambah grup prefs)

**Interfaces:**
- Consumes dari Task 1: semua signature di atas (jangan ubah nama).
- Produces (dipakai Task 3, signature exact):
  - `Future<void> nfcInitOnce()`
  - `class NfcCardRead { final bool ok; final String uid; final String number; final int? balance; final String bank; final List<NfcCardEntry> entries; final bool timeout; final bool nfcError; final String error; const NfcCardRead({required this.ok, required this.uid, required this.number, required this.balance, required this.bank, required this.entries, required this.timeout, required this.nfcError, required this.error}); }`
  - `Future<NfcCardRead> nfcReadCard()`
  - `Future<List<NfcCard>> loadNfcCards()`
  - `Future<void> saveNfcCards(List<NfcCard> cards)`
  - `Future<List<NfcCheck>> loadNfcChecks()`
  - `Future<void> addNfcCheck(NfcCheck check)`

- [ ] **Step 1: Tulis implementasi service**

Create `lib/services/nfc_emoney.dart`:

```dart
// Wrapper baca e-money: init sekali + baca kartu + simpan prefs.
// Read-only: TIDAK ada code path top-up (updateBalance dilarang).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:prepaid_lib_flutter_null_safety/unik_lib_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/nfc_emoney_logic.dart';

bool _nfcInitDone = false;

/// Init sekali (MID dev). Return false TANPA exception = warning saja —
/// terbukti spike: baca tetap sukses. Jangan gate baca di return ini.
Future<void> nfcInitOnce() async {
  if (_nfcInitDone) return;
  try {
    await UnikLibFlutter.initUnikLib('1234567abc', 0);
  } catch (e) {
    debugPrint('nfc init: $e');
  }
  _nfcInitDone = true;
}

class NfcCardRead {
  final bool ok;
  final String uid;
  final String number;
  final int? balance;
  final String bank;
  final List<NfcCardEntry> entries;
  final bool timeout;
  final bool nfcError;
  final String error;
  const NfcCardRead({
    required this.ok,
    required this.uid,
    required this.number,
    required this.balance,
    required this.bank,
    required this.entries,
    required this.timeout,
    required this.nfcError,
    required this.error,
  });
}

Future<NfcCardRead> nfcReadCard() async {
  await nfcInitOnce();
  final uid = <String>[''];
  final num = <String>[''];
  final bal = <String>[''];
  final bank = <String>[''];
  var ok = false;
  var timeout = false;
  var nfcErr = false;
  var err = '';
  try {
    ok = await UnikLibFlutter.getCardInfo(
      uid,
      num,
      bal,
      bank,
      startPooling: true,
      callbackTimeout: (bool t) {
        timeout = t;
      },
      errorNfc: (bool e) {
        nfcErr = e;
      },
    );
  } catch (e) {
    err = '$e';
    ErrorReporter.capture(e, StackTrace.current, context: 'nfc_read');
  }
  var entries = <NfcCardEntry>[];
  if (ok) {
    try {
      final h = <String>[''];
      final hok = await UnikLibFlutter.getHistory(h);
      if (hok) entries = parseNfcHistory(h[0]);
    } catch (e) {
      debugPrint('nfc history: $e');
    }
  }
  try {
    await UnikLibFlutter.stopReader(
      messageSuccess: ok ? 'Baca kartu berhasil' : '',
      messageError: ok ? '' : 'Baca kartu gagal',
    );
  } catch (e) {
    debugPrint('nfc stop: $e');
  }
  return NfcCardRead(
    ok: ok,
    uid: uid[0],
    number: num[0],
    balance: parseNfcBalance(bal[0]),
    bank: nfcBankLabel(bank[0]),
    entries: entries,
    timeout: timeout,
    nfcError: nfcErr,
    error: err,
  );
}

const _kNfcCards = 'nfc_cards';
const _kNfcChecks = 'nfc_history_checks';

Future<List<NfcCard>> loadNfcCards() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kNfcCards);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    final out = <NfcCard>[];
    for (final e in list) {
      final c = NfcCard.tryParse(e);
      if (c != null) out.add(c);
      if (out.length >= maxNfcCards) break;
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<void> saveNfcCards(List<NfcCard> cards) async {
  final capped = capList(cards, maxNfcCards);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kNfcCards,
    jsonEncode([for (final c in capped) c.toJson()]),
  );
}

Future<List<NfcCheck>> loadNfcChecks() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kNfcChecks);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    final out = <NfcCheck>[];
    for (final e in list) {
      final c = NfcCheck.tryParse(e);
      if (c != null) out.add(c);
      if (out.length >= maxNfcChecks) break;
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<void> addNfcCheck(NfcCheck check) async {
  final all = await loadNfcChecks();
  all.insert(0, check);
  final capped = capList(all, maxNfcChecks);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kNfcChecks,
    jsonEncode([for (final c in capped) c.toJson()]),
  );
}
```

- [ ] **Step 2: Tambah test prefs** (append ke `test/nfc_emoney_test.dart`, di dalam `main()`):

```dart
  test('prefs kartu + cek round-trip dan cap', () async {
    SharedPreferences.setMockInitialValues({});
    await saveNfcCards([
      const NfcCard(
        uid: 'U1',
        bank: 'MANDIRI',
        last4: '3976',
        label: 'Mandiri •• 3976',
        walletId: null,
        addedAt: '2026-09-28T00:00:00.000',
      ),
    ]);
    final cards = await loadNfcCards();
    expect(cards.length, 1);
    expect(cards.first.last4, '3976');
    await addNfcCheck(const NfcCheck(
      uid: 'U1',
      bank: 'MANDIRI',
      balance: 100,
      at: '2026-09-28T00:00:00.000',
    ));
    final checks = await loadNfcChecks();
    expect(checks.length, 1);
    expect(checks.first.balance, 100);
  });
```

Tambah import di test: `import 'package:shared_preferences/shared_preferences.dart';` dan `import 'package:ssr_space/services/nfc_emoney.dart';`.

- [ ] **Step 3: Commit lokal**

```bash
git add lib/services/nfc_emoney.dart test/nfc_emoney_test.dart
git commit -m "feat(nfc): service read + prefs kartu & histori cek"
```

### Task 3: Layar + wiring hub + hapus spike

**Files:**
- Create: `lib/screens/lainnya/nfc_cards_screen.dart`
- Modify: `lib/utils/strings.dart` (tambah blok `// NFC e-money` sebelum `};`)
- Modify: `lib/screens/lainnya/other_screen.dart` (ganti tile spike → tile asli, rename `onNfcSpike`→`onNfc`)
- Delete: `lib/screens/lainnya/nfc_spike_screen.dart`

**Interfaces:**
- Consumes dari Task 2: `nfcReadCard`, `NfcCardRead`, `loadNfcCards`, `saveNfcCards`, `loadNfcChecks`, `addNfcCheck`, `NfcCard`, `NfcCheck`; dari Task 1: `maskCardNumber`, `nfcBankLabel`, `NfcEntryDir`; `WalletService().list(orgId)` + prefs `active_org_id` (pola `notif_settings_screen.dart:50-90`); `tr()`; `SectionCard`, `NavTile`, `AppIcons.scan`, `SsrSpace`.

- [ ] **Step 1: Tambah strings `nfc_*`** (sebelum baris `};` penutup `_t`, setelah blok `calm_*`):

```dart
  // NFC e-money
  'nfc_title': {'id': 'E-Money NFC', 'en': 'E-Money NFC'},
  'nfc_sub': {'id': 'Tempel kartu, baca saldo', 'en': 'Tap card, read balance'},
  'nfc_tap': {'id': 'Tempel kartu & baca', 'en': 'Tap card & read'},
  'nfc_scanning': {
    'id': 'Tempelkan kartu ke HP, jangan dilepas…',
    'en': 'Hold the card to the phone…',
  },
  'nfc_stop': {'id': 'Stop', 'en': 'Stop'},
  'nfc_lib_ready': {'id': 'Siap membaca kartu', 'en': 'Ready to read cards'},
  'nfc_no_nfc': {
    'id': 'HP ini tidak mendukung NFC.',
    'en': 'This phone has no NFC support.',
  },
  'nfc_balance': {'id': 'Saldo', 'en': 'Balance'},
  'nfc_card_history': {'id': 'Riwayat kartu', 'en': 'Card history'},
  'nfc_link': {'id': 'Tautkan ke dompet', 'en': 'Link to wallet'},
  'nfc_no_wallet': {'id': 'Tanpa dompet', 'en': 'No wallet'},
  'nfc_save': {'id': 'Simpan kartu', 'en': 'Save card'},
  'nfc_saved': {'id': 'Kartu tersimpan', 'en': 'Card saved'},
  'nfc_checks': {'id': 'Cek terakhir', 'en': 'Recent checks'},
  'nfc_empty': {
    'id': 'Belum ada kartu. Tempel kartu untuk mulai.',
    'en': 'No cards yet. Tap a card to start.',
  },
  'nfc_in': {'id': 'Masuk', 'en': 'In'},
  'nfc_out': {'id': 'Keluar', 'en': 'Out'},
  'nfc_other': {'id': 'Lainnya', 'en': 'Other'},
  'nfc_read_fail': {
    'id': 'Gagal baca kartu. Tempel ulang.',
    'en': 'Card read failed. Tap again.',
  },
  'nfc_delete': {'id': 'Hapus kartu ini?', 'en': 'Delete this card?'},
```

- [ ] **Step 2: Tulis layar**

Create `lib/screens/lainnya/nfc_cards_screen.dart` (komentar `//` biasa, `build()` <50 baris, method kecil `_load/_scan/_save/_remove/_body`):

```dart
// E-Money NFC: daftar kartu tertaut + tempel-baca + histori cek lokal.
// Read-only: tanpa top-up, tanpa transaksi otomatis, tanpa migration.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/services/nfc_emoney.dart';
import 'package:ssr_space/services/nfc_emoney_logic.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';

class NfcCardsScreen extends StatefulWidget {
  const NfcCardsScreen({super.key});

  @override
  State<NfcCardsScreen> createState() => _NfcCardsScreenState();
}

class _NfcCardsScreenState extends State<NfcCardsScreen> {
  bool loading = true;
  bool scanning = false;
  List<NfcCard> cards = [];
  List<NfcCheck> checks = [];
  List<Wallet> wallets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    List<Wallet> ws = [];
    try {
      final orgId = prefs.getString('active_org_id') ?? '';
      if (orgId.isNotEmpty) ws = await WalletService().list(orgId);
    } catch (e) {
      debugPrint('nfc wallets: $e');
    }
    final cs = await loadNfcCards();
    final hs = await loadNfcChecks();
    if (!mounted) return;
    setState(() {
      wallets = ws;
      cards = cs;
      checks = hs;
      loading = false;
    });
  }

  String _walletName(String? id) {
    if (id == null || id.isEmpty) return tr('nfc_no_wallet');
    for (final w in wallets) {
      if (w.id == id) return w.name;
    }
    return tr('nfc_no_wallet');
  }

  Future<void> _scan() async {
    if (scanning) return;
    setState(() => scanning = true);
    final read = await nfcReadCard();
    if (!mounted) return;
    setState(() => scanning = false);
    if (!read.ok || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('nfc_read_fail'))),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ResultSheet(
        read: read,
        wallets: wallets,
        onSave: _save,
      ),
    );
  }

  Future<void> _save(NfcCardRead read, String? walletId) async {
    final now = DateTime.now().toIso8601String();
    final num = read.number.trim();
    final card = NfcCard(
      uid: read.uid,
      bank: read.bank,
      last4: num.length >= 4 ? num.substring(num.length - 4) : '',
      label: '${read.bank} •• ${num.length >= 4 ? num.substring(num.length - 4) : ''}',
      walletId: (walletId == null || walletId.isEmpty) ? null : walletId,
      addedAt: now,
    );
    final all = await loadNfcCards();
    all.removeWhere((c) => c.uid == card.uid);
    all.insert(0, card);
    await saveNfcCards(all);
    if (read.balance != null) {
      await addNfcCheck(NfcCheck(
        uid: read.uid,
        bank: read.bank,
        balance: read.balance!,
        at: now,
      ));
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('nfc_saved'))),
    );
  }

  Future<void> _remove(NfcCard card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('nfc_delete')),
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
    if (ok != true) return;
    final all = await loadNfcCards();
    all.removeWhere((c) => c.uid == card.uid);
    await saveNfcCards(all);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('nfc_title'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(SsrSpace.lg),
              children: [
                _ScanCard(scanning: scanning, onTap: _scan),
                _CardsCard(
                  cards: cards,
                  walletName: _walletName,
                  onRemove: _remove,
                ),
                _ChecksCard(checks: checks),
              ],
            ),
    );
  }
}
```

Widget bantu (satu file yang sama, di bawah state): `_ScanCard` (SectionCard + status `nfc_lib_ready` + FilledButton `nfc_tap` + Stop? — stop di-handle otomatis timeout; tombol Stop panggil `UnikLibFlutter.stopReader`: JANGAN import unik lib di UI — tambah `Future<void> nfcStop()` di Task 2 service bila perlu. **Keputusan: sertakan `nfcStop()` di service** (satu fungsi, tanpa test): `Future<void> nfcStop() async { try { await UnikLibFlutter.stopReader(messageError: 'Dibatalkan'); } catch (e) { debugPrint('nfc stop: $e'); } }`), `_CardsCard` (list kartu: ListTile title=label, subtitle=`mask + bank + wallet`, trailing IconButton delete), `_ChecksCard` (list cek: `amt(balance)` + tanggal), `_ResultSheet` (StatefulWidget: saldo besar `amt()`, bank, dropdown dompet, histori kartu max 11 baris dengan arah `nfc_in/nfc_out/nfc_other`, tombol Simpan).

Aturan nominal: pakai `amt()` dari `utils/mask.dart` (mask-aware). Tanggal histori kartu tampil mentah (format vendor).

- [ ] **Step 3: Ganti wiring hub + hapus spike**

Di `lib/screens/lainnya/other_screen.dart` (baca file dulu, lalu edit exact):
1. Import: ganti `nfc_spike_screen.dart` → `nfc_cards_screen.dart` (komentar `// E-Money NFC.`).
2. `onNfcSpike: () => _push(const NfcSpikeScreen())` → `onNfc: () => _push(const NfcCardsScreen())`.
3. Rename field/ctor `_HubList.onNfcSpike` → `onNfc` (3 titik: field, ctor, penerus ke `_DataSection`).
4. Rename field/ctor `_DataSection.onNfcSpike` → `onNfc`; tile: `title: tr('nfc_title'), subtitle: tr('nfc_sub')`, hapus komentar SPIKE.
5. Hapus file: `git rm lib/screens/lainnya/nfc_spike_screen.dart`.

- [ ] **Step 4: Commit lokal**

```bash
git add lib/screens/lainnya/nfc_cards_screen.dart lib/utils/strings.dart lib/screens/lainnya/other_screen.dart
git rm lib/screens/lainnya/nfc_spike_screen.dart
git commit -m "feat(nfc): layar e-money + wiring hub, hapus spike throwaway"
```

### Task 4: CI final, bump, docs, rilis spike-bersih

**Files:**
- Modify: `.github/workflows/apk.yml` (relabel komentar `SPIKE THROWAWAY`→`NFC e-money`; patch tetap byte-identik)
- Modify: `pubspec.yaml` (`2.4.10+44` → `2.4.11+45`), `lib/utils/app_info.dart` (samakan)
- Modify: `assets/changelog_id.md` (ganti seksi spike → `## Yang baru di 2.4.11` + `Versi terpasang: 2.4.11+45.`)
- Modify: `AGENTS.md`, `AUDIT.md` (catat lokal; baca ekor file dulu)

**Interfaces:** consumes Task 1–3. Produces: CI hijau + APK arm64.

- [ ] **Step 1: Relabel CI (tanpa ubah logika patch)**

Di `.github/workflows/apk.yml`, ganti tiga komentar (kode python JANGAN disentuh):
1. `# SPIKE THROWAWAY NFC (revert bareng kode): build.gradle plugin` → `# NFC e-money (terbukti spike 2026-09-28): build.gradle plugin`
2. Hapus 3 baris `Ronde terakhir...` → ganti `# Tambalan permanen selama pakai prepaid 1.0.1; assert = vonis cepat.`
3. `# SPIKE THROWAWAY NFC (revert bareng kode): izin + fitur hardware.` → `# NFC e-money: izin + fitur hardware.`
4. `# SPIKE THROWAWAY NFC (revert bareng kode): plugin prepaid` (minSdk) → `# NFC e-money: plugin prepaid`
5. `pubspec.yaml`: ganti komentar `# SPIKE THROWAWAY NFC (revert setelah spike): baca saldo e-money.` → `# NFC e-money (read-only, tanpa top-up).`

- [ ] **Step 2: Bump + changelog**

`pubspec.yaml`: `version: 2.4.11+45`. `app_info.dart`: `'2.4.11+45'`. `changelog_id.md`: `Versi terpasang: 2.4.11+45.` + ganti seksi `## Yang baru di 2.4.10+44 (spike sementara, di-revert)` menjadi:

```markdown
## Yang baru di 2.4.11

1. E-Money NFC di Profil → Data: tempel kartu Mandiri/e-money untuk baca saldo, nomor, dan riwayat kartu; kartu bisa diberi label dan ditautkan ke dompet; cek terakhir tersimpan lokal. Baca saja — tanpa top-up dan tanpa transaksi otomatis.
```

- [ ] **Step 3: Catat docs lokal**

`AUDIT.md` §7: tambah baris commit fitur + `2.4.11+45`. `AGENTS.md`: tambah bullet NFC di daftar fitur (§4.5 atau baris status). Baca ekor/posisi terkait dulu; jangan commit docs sendirian (ikut commit Task 4).

- [ ] **Step 4: Commit lokal**

```bash
git add .github/workflows/apk.yml pubspec.yaml lib/utils/app_info.dart assets/changelog_id.md AGENTS.md AUDIT.md
git commit -m "feat(nfc): rilis e-money NFC 2.4.11+45 (relabel CI, bump, docs)"
```

- [ ] **Step 5: Push HANYA atas perintah eksplisit user, lalu pantau**

```bash
git push origin main
gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status
```

Expected: analyze 0 issue, test lulus (termasuk 8 test `nfc_emoney_test`), APK terbangun.

- [ ] **Step 6: Unduh + smoke**

```bash
gh run download <run-id> -n ssr-space-apk-arm64-v8a -D /sdcard/Download/SSR-SPACE/
mv /sdcard/Download/SSR-SPACE/app-arm64-v8a-release.apk /sdcard/Download/SSR-SPACE/SSR-SPACE-2.4.11-45-nfc-arm64.apk
```

Smoke device: buka E-Money NFC → tempel Mandiri → saldo cocok histori → taut dompet → hapus kartu → tanpa-NFC = pesan jujur.

## Self-Review

1. **Spec coverage:** §2 scope/read-only→Task 1–3 + larangan top-up di Global Constraints; §3 file list→Task 3 hapus/wiring + Task 4 relabel; §4 prefs+mask→Task 1 model + Task 2 IO + Task 3 `_save`; §5 parse rules→Task 1 test (init-false→`nfcInitOnce` Task 2); §6 kunci produk→Task 3 (tanpa auto-tx) + strings; §7 testing→Task 1 TDD + Task 4 CI/smoke; §8 risiko→relabel jujur + minSdk tercatat; §9 rilis→Task 4. Tanpa gap.
2. **Placeholder scan:** tanpa TBD/TODO/"nanti"; semua kode tampil penuh kecuali sub-widget Task 3 Step 2 (`_ScanCard/_CardsCard/_ChecksCard/_ResultSheet`) yang didelegasi ke pola file yang sama + constraint eksplisit (build<50, amt(), mounted, tr) — diterima karena pola repo sudah mapan, bukan logika baru.
3. **Type consistency:** `NfcCardRead.balance` (`int?`)→`_save` null-check sebelum `addNfcCheck` ✓; `walletId` (`String?`) konsisten model→sheet→prefs ✓; `entries` (`List<NfcCardEntry>`)→sheet ✓; `capList` generik dipakai dua IO ✓. `ErrorReporter.capture(e, StackTrace.current, context:)` sesuai pemakaian `backup` ✓.
