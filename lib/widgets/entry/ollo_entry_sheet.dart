import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/budget_alert_notify.dart';
import 'package:ssr_space/services/category_icons.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/receipt_kind.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/services/space_service.dart';
import 'package:ssr_space/services/today_widget.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/tx_input_logic.dart';
import 'package:ssr_space/services/tx_validation.dart';
import 'package:ssr_space/services/ai_scan_note_builder.dart';
import 'package:ssr_space/services/receipt_currency.dart';
import 'package:ssr_space/services/receipt_scan_validate.dart';
import 'package:ssr_space/services/vision_scan_service.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/currency.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/entry/voice_draft_sheet.dart';
import 'package:ssr_space/widgets/premium/glass_sheet.dart';
import 'package:ssr_space/widgets/success_lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Evaluasi ekspresi aritmetika sederhana: angka desimal + operator
/// `+ - × ÷` (juga terima `*` `/`). Presedensi standar: `×`/`÷` dulu,
/// lalu `+`/`-`. Mendukung minus unary di awal atau setelah operator.
/// Null bila ekspresi tak valid (termasuk bagi nol).
/// Logika murni (tanpa Flutter) supaya bisa di-test via `flutter test`.
double? evalOlloExpr(String expr) {
  bool isOp(String t) => t == '+' || t == '-' || t == '−' || t == '×' || t == '÷' || t == '*' || t == '/';
  final toks = <String>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isNotEmpty) {
      toks.add(buf.toString());
      buf.clear();
    }
  }

  for (var i = 0; i < expr.length; i++) {
    final ch = expr[i];
    if (isOp(ch)) {
      // Minus unary: di awal atau tepat setelah operator lain.
      if ((ch == '-' || ch == '−') &&
          buf.isEmpty &&
          (toks.isEmpty || isOp(toks.last))) {
        buf.write('-');
        continue;
      }
      flush();
      toks.add(ch);
    } else if ((ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) || ch == '.') {
      buf.write(ch);
    } else if (ch == ' ' || ch == ',') {
      continue; // abaikan spasi/pemisah ribuan bila lolos
    } else {
      return null;
    }
  }
  flush();
  if (toks.isEmpty) return null;

  final vals = <double>[];
  final ops = <String>[];
  for (final t in toks) {
    if (isOp(t)) {
      ops.add(t);
    } else {
      final v = double.tryParse(t);
      if (v == null) return null;
      vals.add(v);
    }
  }
  if (vals.isEmpty || vals.length != ops.length + 1) return null;

  // Pass 1: × ÷ * /
  var i = 0;
  while (i < ops.length) {
    final op = ops[i];
    if (op == '×' || op == '*' || op == '÷' || op == '/') {
      final a = vals[i];
      final b = vals[i + 1];
      double r;
      if (op == '×' || op == '*') {
        r = a * b;
      } else {
        if (b == 0) return null;
        r = a / b;
      }
      vals[i] = r;
      vals.removeAt(i + 1);
      ops.removeAt(i);
    } else {
      i++;
    }
  }
  // Pass 2: + − (sisa operator hanya + dan -)
  var acc = vals[0];
  for (var j = 0; j < ops.length; j++) {
    final op = ops[j];
    if (op == '+') {
      acc += vals[j + 1];
    } else if (op == '-' || op == '−') {
      acc -= vals[j + 1];
    } else {
      return null;
    }
  }
  return acc;
}

/// Jalur simpan TUNGGAL untuk entry Ollo & draft suara (TASK C):
/// validasi dilakukan pemanggil; di sini add + catat pemakaian dompet +
/// alert budget + snapshot widget. Null = sukses; non-null = pesan
/// error (sudah lewat tr()).
Future<String?> persistOlloTx({
  required String orgId,
  required String type,
  required double amountIdr,
  String? walletId,
  String? toWalletId,
  String? category,
  String? title,
  String? note,
  required DateTime day,
  TimeOfDay? time,
  bool useTime = false,
}) async {
  final when = txWhen(
    day,
    hour: useTime ? time?.hour : null,
    minute: useTime ? time?.minute : null,
  );
  // Model transaksi tak punya kolom judul (tanpa migration): judul
  // digabung ke depan catatan.
  final parts = <String>[
    if (title != null && title.trim().isNotEmpty) title.trim(),
    if (note != null && note.trim().isNotEmpty) note.trim(),
  ];
  try {
    await TransactionService().add(
      orgId: orgId,
      type: type,
      amount: amountIdr,
      walletId: walletId,
      toWalletId: type == 'transfer' ? toWalletId : null,
      category: category,
      note: parts.join(' · '),
      date: when.date,
      createdAt: when.createdAt,
    );
    if (walletId != null) {
      try {
        await noteWalletUsed(walletId);
      } catch (_) {}
    }
    if (type == 'transfer' && toWalletId != null) {
      try {
        await noteWalletUsed(toWalletId);
      } catch (_) {}
    }
    // Sama seperti sheet existing: cek alert budget + snapshot widget.
    unawaited(BudgetAlertNotify.check(orgId));
    unawaited(refreshOlloWalletCache(orgId).catchError((_) {}));
    return null;
  } catch (e) {
    return olloTxError(e);
  }
}

/// Pesan error jujur (bukan teknis) untuk hasil [persistOlloTx].
String olloTxError(Object e) {
  if (e is SpaceException) return e.message;
  if (e is PostgrestException) {
    switch (e.code) {
      case '42501':
        return tr('tx_err_42501');
      case '23503':
        return tr('tx_err_23503');
      case '23514':
        return tr('tx_err_23514');
      case '23505':
        return tr('tx_err_23505');
    }
  }
  return tr('tx_err_generic').replaceFirst('{a}', tr('tx_act_save'));
}

/// Bottom sheet entri transaksi gaya Ollo: tab Expense/Income/Transfer,
/// lingkaran kategori pastel, chip subkategori, amount besar + numpad
/// kalkulator, lalu simpan lewat [TransactionService] yang sama dengan
/// sheet input existing. Kembalikan bila pemanggil perlu muat ulang —
/// fungsi publik ini me-return void sesuai kontrak (sheet menutup
/// sendiri setelah simpan sukses). [initialDraft] (TASK C, draft suara)
/// mengisi form dari hasil parse suara tanpa merusak pemanggil lama.
Future<void> showOlloEntrySheet(BuildContext context,
    {VoiceDraft? initialDraft, bool autoScan = false}) async {
  final orgId = await activeOrgId();
  if (orgId.isEmpty || !context.mounted) return;
  // Muat dompet seperti openTxInputSheet: cache dulu, fetch bila kosong.
  final cached = WalletCache.peek(orgId);
  late final List<Wallet> wallets;
  if (cached != null) {
    wallets = cached.wallets;
    unawaited(refreshOlloWalletCache(orgId));
  } else {
    try {
      final results = await Future.wait([
        WalletService().list(orgId),
        WalletService().balances(orgId).catchError(
              (_) => <WalletBalance>[],
            ),
      ]);
      wallets = results[0] as List<Wallet>;
      WalletCache.store(orgId, wallets, {
        for (final b in (results[1] as List<WalletBalance>)) b.walletId: b.balance,
      });
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('conn_error'))));
      return;
    }
  }
  if (!context.mounted) return;
  await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GlassSheetScaffold(
      // Sudah ada drag handle sendiri di bawah.
      showHandle: false,
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.93,
        child: _OlloEntrySheet(
          orgId: orgId,
          wallets: wallets,
          initialDraft: initialDraft,
          autoScan: autoScan,
        ),
      ),
    ),
  );
}

/// Segarkan cache dompet diam-diam untuk pembukaan sheet berikutnya.
/// Tak pernah melempar; sheet yang terbuka pakai snapshot.
Future<void> refreshOlloWalletCache(String orgId) async {
  try {
    final results = await Future.wait([
      WalletService().list(orgId),
      WalletService().balances(orgId).catchError((_) => <WalletBalance>[]),
    ]);
    WalletCache.store(orgId, results[0] as List<Wallet>, {
      for (final b in (results[1] as List<WalletBalance>)) b.walletId: b.balance,
    });
  } catch (_) {}
}

class _OlloEntrySheet extends StatefulWidget {
  final String orgId;
  final List<Wallet> wallets;
  final VoiceDraft? initialDraft;

  /// Buka langsung picu dialog scan struk (dari menu + > Scan).
  final bool autoScan;

  const _OlloEntrySheet({
    required this.orgId,
    required this.wallets,
    this.initialDraft,
    this.autoScan = false,
  });

  @override
  State<_OlloEntrySheet> createState() => _OlloEntrySheetState();
}

class _OlloEntrySheetState extends State<_OlloEntrySheet> {
  // Jenis: 'out' (Expense, default) | 'in' (Income) | 'transfer'.
  String _type = 'out';
  String _cat = '';
  String _sub = '';
  bool _tagReimburse = false;
  bool _tagSplit = false;
  bool _tagCc = false;

  // Buffer digit nominal (bukan ValueNotifier: rebuild via setState saja).
  String _digits = '';
  // Mode kalkulator: _expr menampung ekspresi, bukan digit polos.
  bool _calcMode = false;
  String _expr = '';

  String _currencyCode = 'IDR';
  String? _walletId;
  String? _toWalletId;

  DateTime _day = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _useTime = false;

  bool _scanning = false;
  bool _saving = false;
  String? _formErr;

  final _titleC = TextEditingController();
  final _noteC = TextEditingController();

  int get _dec => kCurrencyDecimals(_currencyCode);

  @override
  void initState() {
    super.initState();
    final cats = appCategories.value;
    _cat = cats.contains('Belanja')
        ? 'Belanja'
        : (cats.isEmpty ? '' : cats.first);
    if (widget.wallets.isNotEmpty) {
      _walletId = widget.wallets.first.id;
      _currencyCode = widget.wallets.first.currency;
    }
    _applyInitialDraft();
    if (widget.autoScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scan();
      });
    }
  }

  /// Prefill dari draft suara: tipe, kategori, dompet, nominal, judul,
  /// catatan, tanggal. Default tak berubah bila draft null.
  void _applyInitialDraft() {
    final d = widget.initialDraft;
    if (d == null) return;
    _type = d.type == 'in' ? 'in' : 'out';
    final cats = appCategories.value;
    if (d.category != null && cats.contains(d.category)) {
      _cat = d.category!;
      _sub = '';
    }
    final wn = d.walletName?.trim().toLowerCase();
    if (wn != null && wn.isNotEmpty) {
      for (final w in widget.wallets) {
        if (w.name.toLowerCase() == wn) {
          _walletId = w.id;
          _currencyCode = w.currency;
          break;
        }
      }
    }
    // Nominal: IDR -> mata uang dompet -> buffer digit minor.
    final major = _fromIdr(d.amount, _currencyCode);
    var mult = 1;
    for (var i = 0; i < _dec; i++) {
      mult *= 10;
    }
    _digits = (major * mult).round().toString();
    _titleC.text = d.title;
    _noteC.text = d.note;
    _day = DateTime(d.dateTime.year, d.dateTime.month, d.dateTime.day);
  }

  @override
  void dispose() {
    _titleC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  // ---- Konversi mata uang berparameter (cermin CurrencyService.toIdr /
  // convert, tapi memakai kode pilihan sheet, bukan currencyCode global).
  double _toIdr(double displayed, String code) {
    if (code == 'IDR') return displayed;
    final r = CurrencyService.rates[code];
    if (r == null || r == 0) return displayed;
    return displayed / r;
  }

  double _fromIdr(double idr, String code) {
    if (code == 'IDR') return idr;
    final r = CurrencyService.rates[code];
    if (r == null || r == 0) return idr;
    return idr * r;
  }

  /// Nominal mayor tampil (mata uang pilihan) dari buffer aktif.
  double get _major {
    if (_calcMode) return evalOlloExpr(_expr) ?? 0;
    return majorFromDigits(_digits, dec: _dec);
  }

  /// Nominal IDR untuk disimpan (assert > 0 di TransactionService.add).
  double get _idr => _toIdr(_major, _currencyCode);

  // ---- Tampilan amount ----
  String _grouped(String d) {
    if (d.isEmpty) return '0';
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && (d.length - i) % 3 == 0) b.write('.');
      b.write(d[i]);
    }
    return b.toString();
  }

  String _amountText() {
    if (_calcMode) return _expr.isEmpty ? '0' : _expr;
    if (_dec <= 0) return _grouped(_digits);
    final v = majorFromDigits(_digits, dec: _dec);
    final fixed = v.toStringAsFixed(_dec);
    final parts = fixed.split('.');
    return '${_grouped(parts[0])}.${parts[1]}';
  }

  String _currencySymbol() {
    for (final c in supportedCurrencies) {
      if (c.code == _currencyCode) return c.symbol.trim();
    }
    return _currencyCode;
  }

  // ---- Kategori & sub ----
  List<String> get _cats => appCategories.value;

  /// Opsi chip subkategori: diambil dari kategori existing yang relevan
  /// (bukan struktur data baru). Income: kategori berbau pemasukan;
  /// Expense: semua kategori selain yang dipilih. Ketuk = isi sub
  /// (disimpan sebagai 'Top > Sub' seperti field sub sheet existing).
  List<String> _subOptions() {
    final rest = _cats.where((c) => c != _cat).toList();
    if (_type == 'in') {
      const keys = [
        'gaji', 'upah', 'bonus', 'bisnis', 'usaha', 'invest', 'hadiah',
        'pendapatan', 'pemasukan', 'salary', 'income', 'fee', 'komisi',
        'thr', 'dividen', 'royalti',
      ];
      final hits = rest
          .where((c) => keys.any((k) => c.toLowerCase().contains(k)))
          .toList();
      if (hits.isNotEmpty) return hits;
    }
    return rest;
  }

  Color _catColor(BuildContext context, String cat, int index) {
    final metaIdx = categoryMeta.value[cat]?.color ?? (index % 12);
    return metaSlotColor(context, metaIdx);
  }

  void _switchType(String t) {
    if (_type == t) return;
    setState(() {
      _type = t;
      _sub = '';
      _formErr = null;
    });
  }

  // ---- Numpad ----
  void _pressDigit(String key) {
    setState(() {
      _formErr = null;
      if (_calcMode) {
        _expr += key;
      } else {
        _digits = numpadAppend(_digits, key);
      }
    });
  }

  void _pressDot() {
    setState(() {
      _formErr = null;
      if (_calcMode) {
        if (!_expr.contains('.')) _expr += _expr.isEmpty ? '0.' : '.';
      } else if (_dec > 0) {
        // Buffer digit minor: titik tak dipakai (desimal dari posisi
        // digit), abaikan agar konsisten dengan TxNumpad existing.
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_calcMode) {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
      } else {
        _digits = numpadBackspace(_digits);
      }
    });
  }

  void _toggleCalc() {
    setState(() {
      _formErr = null;
      if (!_calcMode) {
        // Masuk mode ekspresi: bawa nominal saat ini sebagai awal
        // (mayor tampil, tanpa pemisah ribuan).
        var s = majorFromDigits(_digits, dec: _dec).toString();
        if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
        _expr = _digits.isEmpty ? '' : s;
        _calcMode = true;
      } else {
        _evaluateOrStay();
      }
    });
  }

  void _pressOp(String op) {
    setState(() {
      _formErr = null;
      if (_expr.isEmpty) {
        if (op == '-') _expr = '-';
        return;
      }
      final last = _expr[_expr.length - 1];
      const ops = ['+', '-', '×', '÷'];
      if (ops.contains(last)) {
        _expr = _expr.substring(0, _expr.length - 1) + op;
      } else {
        _expr += op;
      }
    });
  }

  /// Evaluasi (tombol "="): valid -> isi buffer digit + keluar mode
  /// kalkulator; tak valid -> tampilkan pesan, tetap di mode ekspresi.
  /// Return true bila berhasil / tidak dalam mode kalkulator.
  bool _evaluateOrStay() {
    if (!_calcMode) return true;
    final v = evalOlloExpr(_expr);
    if (v == null || v.isNaN || v.isInfinite || v < 0) {
      _formErr = tr('entry_calc_err');
      return false;
    }
    _digits = digitsFromMajor(v, dec: _dec);
    _expr = '';
    _calcMode = false;
    _formErr = null;
    return true;
  }

  // ---- Tanggal/waktu (picker existing) ----
  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: _time);
    if (!mounted) return;
    setState(() {
      _day = d;
      if (t != null) {
        _time = t;
        _useTime = true;
      }
    });
  }

  String _dateLine1() {
    final m = _day.month.toString().padLeft(2, '0');
    return '${_day.day} ${tr('s$m')}';
  }

  String _dateLine2() =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  // ---- Dompet & mata uang ----
  Wallet? get _wallet {
    for (final w in widget.wallets) {
      if (w.id == _walletId) return w;
    }
    return null;
  }

  Future<void> _pickWallet() async {
    if (widget.wallets.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final w in widget.wallets)
              ListTile(
                title: Text(w.name),
                trailing: Text(
                  w.currency,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.outline),
                ),
                selected: w.id == _walletId,
                onTap: () => Navigator.pop(ctx, w.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _walletId = picked;
      _formErr = null;
      // Default mata uang mengikuti dompet yang dipilih (Fase 5).
      final w = _wallet;
      if (w != null) _currencyCode = w.currency;
      if (_type == 'transfer' && _toWalletId == _walletId) _toWalletId = null;
    });
  }

  Future<void> _pickToWallet() async {
    final others = widget.wallets.where((w) => w.id != _walletId).toList();
    if (others.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final w in others)
              ListTile(
                title: Text(w.name),
                trailing: Text(
                  w.currency,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.outline),
                ),
                selected: w.id == _toWalletId,
                onTap: () => Navigator.pop(ctx, w.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _toWalletId = picked;
      _formErr = null;
    });
  }

  Future<void> _pickCurrency() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final en = localeCode.value == 'en';
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in supportedCurrencies)
                ListTile(
                  title: Text('${c.code} · ${c.symbol.trim()}'),
                  subtitle: Text(en ? c.nameEn : c.nameId),
                  selected: c.code == _currencyCode,
                  onTap: () => Navigator.pop(ctx, c.code),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _currencyCode = picked);
  }

  // ---- Scan struk (alur existing: scanReceiptVision, prefill saja) ----
  Future<void> _scan() async {
    final src = await showGlassDialog<ImageSource>(
      context: context,
      title: Text(tr('rcp_scan')),
      content: Text(tr('mode_vision_s')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ImageSource.camera),
          child: Text(tr('rcp_camera')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ImageSource.gallery),
          child: Text(tr('rcp_gallery')),
        ),
      ],
    );
    if (src == null || !mounted) return;
    setState(() {
      _scanning = true;
      _formErr = null;
    });
    try {
      final out = await scanReceiptVision(src);
      if (!mounted) return;
      setState(() => _scanning = false);
      if (out == null) return;
      final data = await applyFxConversion(out.data);
      if (!mounted) return;
      final scanNote = await buildScanNoteFor(data);
      if (!mounted) return;
      _applyScan(data, out.category, scanNote: scanNote);
      // Batch 284 tahap A: validator struk — permukaan ini tanpa sheet
      // hasil, jadi peringatan tampil sebagai SnackBar (tak memblokir).
      final warns = await validateReceiptData(data);
      unawaited(recordScanAmount(data));
      if (warns.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warns.map((w) => w.message).join('\n'))),
        );
      }
    } on VisionScanException catch (e) {
      if (!mounted) return;
      if (e.trKey == 'q_ai_exceeded') {
        setState(() => _scanning = false);
        await requirePro(context, tr('q_ai_exceeded'));
        return;
      }
      setState(() {
        _scanning = false;
        _formErr = e.detail == null
            ? tr(e.trKey)
            : '${tr(e.trKey)}\n${e.detail}';
      });
    }
  }

  /// Prefill form dari hasil struk — cermin _applyReceiptPrefill di
  /// tx_input_sheet (nominal, tanggal, kategori, catatan). Tanpa simpan.
  void _applyScan(ReceiptData r, String? aiCategory,
      {String? scanNote}) {
    setState(() {
      if (r.amount != null && r.amount! > 0) {
        _type = 'out';
        _calcMode = false;
        _expr = '';
        _digits = digitsFromMajor(_fromIdr(r.amount!, _currencyCode), dec: _dec);
      }
      if (r.date != null) _day = r.date!;
      final dt = r.detailText;
      // Batch 284 tahap C: sama seperti tx_input_sheet — NoteBuilder
      // menang bila tersedia; '' = saklar mati -> catatan kosong.
      _noteC.text = scanNote ??
          ((dt != null && dt.trim().isNotEmpty) ? dt : receiptNote(r));
      final cats = _cats;
      var sel = cats.contains('Belanja')
          ? 'Belanja'
          : (cats.isEmpty ? '' : cats.first);
      final aiCat = aiCategory?.trim();
      if (aiCat != null &&
          aiCat.isNotEmpty &&
          cats.any((c) => c.trim().toLowerCase() == aiCat.toLowerCase())) {
        sel = cats
            .firstWhere((c) => c.trim().toLowerCase() == aiCat.toLowerCase());
      } else {
        final sug = suggestReceiptCategory(
          merchant: r.merchant,
          items: r.items,
          categories: cats,
        );
        if (sug != null) sel = sug;
      }
      _cat = sel;
      _sub = '';
    });
  }

  // ---- Simpan (jalur existing: TransactionService.add) ----
  String _buildNote() {
    final parts = <String>[];
    final title = _titleC.text.trim();
    if (title.isNotEmpty) parts.add(title);
    final tags = <String>[
      if (_tagReimburse) tr('entry_tag_reimburse'),
      if (_tagSplit) tr('entry_tag_split'),
      if (_tagCc) tr('entry_tag_cc'),
    ];
    if (tags.isNotEmpty) parts.add('[${tags.join('][')}]');
    final note = _noteC.text.trim();
    if (note.isNotEmpty) parts.add(note);
    return parts.join(' · ');
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_evaluateOrStay()) {
      // Ekspresi tak valid: _formErr sudah diisi, rebuild untuk tampil.
      setState(() {});
      return;
    }
    final idr = _idr;
    // Validasi existing: pesan error dari tx_validation (txv_*).
    final msg = validateTxInput(
      amount: idr,
      walletId: _walletId,
      type: _type,
      toWalletId: _toWalletId,
    );
    if (msg != null) {
      setState(() => _formErr = msg);
      return;
    }
    setState(() {
      _saving = true;
      _formErr = null;
    });
    try {
      final when = txWhen(
        _day,
        hour: _useTime ? _time.hour : null,
        minute: _useTime ? _time.minute : null,
      );
      // Model transaksi tak punya kolom judul (tanpa migration):
      // judul digabung ke depan catatan.
      final cat = _type == 'transfer'
          ? null
          : formatCategory(_cat, _sub.isEmpty ? null : _sub);
      await TransactionService().add(
        orgId: widget.orgId,
        type: _type,
        amount: idr,
        walletId: _walletId,
        toWalletId: _type == 'transfer' ? _toWalletId : null,
        category: cat,
        note: _buildNote(),
        date: when.date,
        createdAt: when.createdAt,
      );
      try {
        if (_walletId != null) await noteWalletUsed(_walletId!);
        if (_type == 'transfer' && _toWalletId != null) {
          await noteWalletUsed(_toWalletId!);
        }
      } catch (_) {}
      // Sama seperti sheet existing: cek alert budget + snapshot widget.
      unawaited(BudgetAlertNotify.check(widget.orgId));
      unawaited(refreshBudgetWidgetSnapshot(widget.orgId).catchError((_) {}));
      if (!mounted) return;
      await showSuccessFlash(context);
      if (!mounted) return;
      Navigator.pop(context, 'saved');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formErr = _txError(e);
      });
    }
  }

  /// Cermin _txError di tx_input_sheet: pesan jujur, bukan teknis.
  String _txError(Object e) {
    if (e is SpaceException) return e.message;
    if (e is PostgrestException) {
      switch (e.code) {
        case '42501':
          return tr('tx_err_42501');
        case '23503':
          return tr('tx_err_23503');
        case '23514':
          return tr('tx_err_23514');
        case '23505':
          return tr('tx_err_23505');
      }
    }
    return tr('tx_err_generic').replaceFirst('{a}', tr('tx_act_save'));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: scheme.outlineVariant,
            ),
          ),
          const SizedBox(height: 10),
          _topRow(context, scheme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _categoryRow(context, scheme),
                  if (_type != 'transfer') ...[
                    const SizedBox(height: 10),
                    _subChips(context, scheme),
                  ],
                  const SizedBox(height: 10),
                  _actionChips(scheme),
                  const SizedBox(height: 18),
                  _amountSection(scheme),
                  const SizedBox(height: 14),
                  _titleField(scheme),
                  const SizedBox(height: 8),
                  _noteWalletSection(scheme),
                  if (_formErr != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formErr!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          if (_calcMode) _operatorRow(scheme),
          _numpad(scheme),
        ],
      ),
    );
  }

  Widget _topRow(BuildContext context, ColorScheme scheme) {
    final tabs = <(String, String)>[
      ('out', tr('tx_out')),
      ('in', tr('tx_in')),
      ('transfer', tr('tx_transfer')),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: scheme.surfaceContainerHighest,
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  for (final (value, label) in tabs)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchType(value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: _type == value
                                ? DribTokens.navy
                                : Colors.transparent,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _type == value
                                  ? Colors.white
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHighest,
            ),
            child: IconButton(
              onPressed: _scanning ? null : _scan,
              icon: _scanning
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryRow(BuildContext context, ColorScheme scheme) {
    final cats = _cats;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = cats[i];
          final selected = c == _cat;
          final full = _catColor(context, c, i);
          return GestureDetector(
            onTap: () => setState(() {
              _cat = c;
              _sub = '';
            }),
            child: SizedBox(
              width: 66,
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? full
                          : full.withValues(alpha: 0.15),
                    ),
                    alignment: Alignment.center,
                    child: DuoIcon(
                      iconForCategory(c),
                      size: 26,
                      color: selected ? Colors.white : full,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _subChips(BuildContext context, ColorScheme scheme) {
    final opts = _subOptions();
    if (opts.isEmpty) return const SizedBox.shrink();
    final accent = _catColor(context, _cat, _cats.indexOf(_cat));
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: opts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = opts[i];
          final selected = _sub == label;
          return GestureDetector(
            onTap: () => setState(() {
              _sub = selected ? '' : label;
            }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color:
                    selected ? accent : scheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _actionChips(ColorScheme scheme) {
    final chips = <(String, bool, void Function(bool))>[
      (tr('entry_tag_reimburse'), _tagReimburse, (v) => _tagReimburse = v),
      (tr('entry_tag_split'), _tagSplit, (v) => _tagSplit = v),
      (tr('entry_tag_cc'), _tagCc, (v) => _tagCc = v),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, active, set) = chips[i];
          return GestureDetector(
            onTap: () => setState(() => set(!active)),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: active
                    ? DribTokens.navy
                    : scheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: active ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _amountSection(ColorScheme scheme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickCurrency,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: scheme.surfaceContainerHighest,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currencySymbol(),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down,
                        size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _amountText(),
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          tr('entry_amount_hint'),
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _fieldShell(ColorScheme scheme, Widget child) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: child,
    );
  }

  Widget _titleField(ColorScheme scheme) {
    return _fieldShell(
      scheme,
      Row(
        children: [
          Icon(Icons.title, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _titleC,
              decoration: InputDecoration(
                hintText: tr('entry_title_hint'),
                hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteWalletSection(ColorScheme scheme) {
    final noteField = _fieldShell(
      scheme,
      Row(
        children: [
          Icon(Icons.note_alt_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _noteC,
              decoration: InputDecoration(
                hintText: tr('entry_note_hint'),
                hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
    if (_type == 'transfer') {
      return Column(
        children: [
          noteField,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _walletTile(scheme, false)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward,
                    color: scheme.onSurfaceVariant),
              ),
              Expanded(child: _walletTile(scheme, true)),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 3, child: noteField),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: _walletTile(scheme, false)),
      ],
    );
  }

  /// Tile dropdown dompet. [to] = dompet tujuan (mode transfer).
  Widget _walletTile(ColorScheme scheme, bool to) {
    final id = to ? _toWalletId : _walletId;
    Wallet? w;
    for (final x in widget.wallets) {
      if (x.id == id) {
        w = x;
        break;
      }
    }
    final label = to
        ? tr('entry_to_wallet')
        : (w == null ? tr('txv_wallet') : w.name);
    final value = to ? (w?.name ?? tr('entry_to_wallet')) : label;
    return GestureDetector(
      onTap: to ? _pickToWallet : _pickWallet,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: scheme.surfaceContainerHighest,
          border: to && _toWalletId == null
              ? Border.fromBorderSide(BorderSide(color: scheme.outlineVariant))
              : null,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (to)
                    Text(
                      tr('entry_to_wallet'),
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant),
                    ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _olloKey(
    ColorScheme scheme,
    Widget child,
    VoidCallback onTap, {
    Color? bg,
    Color? fg,
    VoidCallback? onLongPress,
  }) {
    final fore = fg ?? scheme.onSurface;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: bg ?? scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            onLongPress: onLongPress,
            child: SizedBox(
              height: 56,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(color: fore, size: 24),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: fore,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _operatorRow(ColorScheme scheme) {
    const ops = ['+', '-', '×', '÷'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          for (final op in ops)
            _olloKey(
              scheme,
              Text(op, style: const TextStyle(fontSize: 24)),
              () => _pressOp(op),
              bg: DribTokens.navy.withValues(alpha: 0.08),
              fg: DribTokens.navy,
            ),
        ],
      ),
    );
  }

  Widget _numpad(ColorScheme scheme) {
    Widget digit(String k) => _olloKey(
          scheme,
          Text(k),
          () => _pressDigit(k),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              digit('1'),
              digit('2'),
              digit('3'),
              _olloKey(
                scheme,
                const Icon(Icons.backspace_outlined),
                _backspace,
                bg: scheme.errorContainer,
                fg: scheme.onErrorContainer,
                onLongPress: () => setState(() {
                  if (_calcMode) {
                    _expr = '';
                  } else {
                    _digits = '';
                  }
                }),
              ),
            ],
          ),
          Row(
            children: [
              digit('4'),
              digit('5'),
              digit('6'),
              _olloKey(
                scheme,
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('+ −', style: TextStyle(fontSize: 17)),
                    Text('× =', style: TextStyle(fontSize: 17)),
                  ],
                ),
                _toggleCalc,
                bg: _calcMode
                    ? DribTokens.navy
                    : scheme.surfaceContainerHighest,
                fg: _calcMode ? Colors.white : scheme.onSurface,
              ),
            ],
          ),
          Row(
            children: [
              digit('7'),
              digit('8'),
              digit('9'),
              _olloKey(
                scheme,
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dateLine1(),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _dateLine2(),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                _pickDateTime,
              ),
            ],
          ),
          Row(
            children: [
              _olloKey(scheme, const Text('.'), _pressDot),
              digit('0'),
              _olloKey(scheme, const Text('000'), () => _pressDigit('000')),
              _olloKey(
                scheme,
                _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 28),
                _save,
                bg: DribTokens.navy,
                fg: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
