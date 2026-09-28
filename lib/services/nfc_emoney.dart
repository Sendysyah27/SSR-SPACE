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

Future<void> nfcStop() async {
  try {
    await UnikLibFlutter.stopReader(messageError: 'Dibatalkan');
  } catch (e) {
    debugPrint('nfc stop: $e');
  }
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
