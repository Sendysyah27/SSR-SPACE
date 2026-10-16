import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';
import 'package:ssr_space/screens/lainnya/ai_draft_screen.dart';
import 'package:ssr_space/services/ai_draft.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/budget_alert_notify.dart';
import 'package:ssr_space/services/category_icons.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/offline_cache.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/quick_input_parse.dart';
import 'package:ssr_space/services/receipt_kind.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/services/receipt_scan_service.dart';
import 'package:ssr_space/services/vision_scan_service.dart';
import 'package:ssr_space/widgets/input_mode_sheet.dart';
import 'package:ssr_space/services/space_service.dart';
import 'package:ssr_space/services/today_widget.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/tx_input_logic.dart';
import 'package:ssr_space/services/tx_validation.dart';
import 'package:ssr_space/services/voice_native.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/services/wallet_usage.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/category_chips.dart';
import 'package:ssr_space/widgets/premium/glass_sheet.dart';
import 'package:ssr_space/widgets/premium/premium_button.dart';
import 'package:ssr_space/widgets/receipt_result_sheet.dart';
import 'package:ssr_space/widgets/scan_overlay.dart';
import 'package:ssr_space/widgets/success_lottie.dart';
import 'package:ssr_space/widgets/restyle/swipe_to_confirm.dart';
import 'package:ssr_space/widgets/tx_numpad.dart';
import 'package:ssr_space/widgets/tx_row.dart';
import 'package:ssr_space/widgets/tx_type_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pintu masuk tunggal catat/ubah transaksi dari mana pun:
/// tombol + tengah navbar, aksi + AppBar riwayat, ketuk TxRow (edit).
/// Memuat workspace + dompet sendiri, buka sheet, beri umpan balik,
/// kembalikan true bila pemanggil perlu muat ulang.
Future<bool> openTxInputSheet(
  BuildContext context, {
  SaasTransaction? editing,
  String? initialType,
  double? initialAmountIdr,
  String? initialCategory,
  String? initialWalletId,
  String? initialNote,
  TxInputMode? initialMode,
}) async {
  final orgId = await activeOrgId();
  if (orgId.isEmpty || !context.mounted) return false;
  // Cache dulu: sheet tampil segera dari snapshot (stale ≤60 dtk wajar
  // untuk label dropdown); penyegaran diam-diam mengisi buka berikutnya.
  // Jalur dingin (cache kosong) mengambil list + saldo paralel.
  final cached = WalletCache.peek(orgId);
  late final List<Wallet> wallets;
  Map<String, double> balances = {};
  if (cached != null) {
    wallets = cached.wallets;
    balances = cached.balances;
    unawaited(_refreshWalletCache(orgId));
  } else {
    try {
      final results = await Future.wait([
        WalletService().list(orgId),
        WalletService().balances(orgId).catchError(
              (_) => <WalletBalance>[],
            ),
      ]);
      wallets = results[0] as List<Wallet>;
      balances = {
        for (final b in (results[1] as List<WalletBalance>)) b.walletId: b.balance,
      };
      WalletCache.store(orgId, wallets, balances);
    } catch (_) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('conn_error'))));
      return false;
    }
  }
  if (!context.mounted) return false;
  final res = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GlassSheetScaffold(
      // TxInputSheet sudah punya _DragHandle sendiri.
      showHandle: false,
      child: TxInputSheet(
        orgId: orgId,
        wallets: wallets,
        balances: balances,
        editing: editing,
        initialType: initialType,
        initialAmountIdr: initialAmountIdr,
        initialCategory: initialCategory,
        initialWalletId: initialWalletId,
        initialNote: initialNote,
        initialMode: initialMode,
      ),
    ),
  );
  if (!context.mounted || res == null) return false;
  if (res == 'deleted') {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('tx_deleted'))));
  } else if (editing != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('tx_updated'))));
  } else {
    await showSuccessFlash(context);
  }
  return true;
}

/// Segarkan cache dompet diam-diam untuk pembukaan sheet berikutnya.
/// Tak pernah melempar; sheet yang sedang terbuka pakai snapshot.
Future<void> _refreshWalletCache(String orgId) async {
  try {
    final wallets = await WalletService().list(orgId);
    Map<String, double> balances = {};
    try {
      final bals = await WalletService().balances(orgId);
      balances = {for (final b in bals) b.walletId: b.balance};
    } catch (_) {}
    WalletCache.store(orgId, wallets, balances);
  } catch (_) {}
}

/// Sheet input transaksi premium: display nominal + numpad custom,
/// jenis, tanggal (wajib) + jam (opsional), dompet, kategori, catatan.
/// Keyboard sistem hanya muncul untuk kategori/catatan; nominal murni numpad.
class TxInputSheet extends StatefulWidget {
  final String orgId;
  final List<Wallet> wallets;
  final Map<String, double> balances;
  final SaasTransaction? editing;

  /// Prefill untuk saran tagihan rutin (dipakai bila [editing] null).
  final String? initialType;
  final double? initialAmountIdr;
  final String? initialCategory;
  final String? initialWalletId;
  final String? initialNote;

  /// Mode dari chooser +: langsung picu scan/voice saat sheet dibuka.
  final TxInputMode? initialMode;

  const TxInputSheet({
    super.key,
    required this.orgId,
    required this.wallets,
    required this.balances,
    this.editing,
    this.initialType,
    this.initialAmountIdr,
    this.initialCategory,
    this.initialWalletId,
    this.initialNote,
    this.initialMode,
  });

  @override
  State<TxInputSheet> createState() => _TxInputSheetState();
}

class _TxInputSheetState extends State<TxInputSheet> {
  late String type;
  late final ValueNotifier<String> digits;
  late DateTime day;
  late bool useTime;
  late TimeOfDay time;
  String? walletId;
  String? toWalletId;
  Timer? _quickDeb;
  final quickC = TextEditingController();
  final catC = TextEditingController();
  final subC = TextEditingController();
  final noteC = TextEditingController();
  bool saving = false;
  String? formErr;
  String? amountErr;
  String? walletErr;
  String? toWalletErr;
  String? _quickStatus;
  bool _showSub = false;
  String? _scanOrigin;
  // Voice input native: dengar -> tulis ke quickC -> pipeline ketik-cepat.
  // Ketersediaan dicek SEKALI saat sheet dibuka (tanpa race); tap hanya
  // dengar/berhenti. Tanpa plugin (channel ssr_space/voice).
  final _voice = VoiceNative();
  bool _listening = false;
  bool _voiceReady = false;
  Future<void>? _voiceInitFuture;
  String? _voiceErr;
  // Wizard: 0 = jenis+kategori, 1 = form. Mode edit langsung ke form.
  int _step = 0;
  String? _selCat;
  bool _scanning = false;
  String? _scanErr;

  /// Sebab jujur kegagalan AI terakhir (kode + pesan asli), tampil di
  /// dialog diagnosis teks mentah. Reset tiap scan baru.
  String? _aiErrDetail;

  int get _dec => kCurrencyDecimals(currencyCode.value);
  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _voiceInitFuture = _initVoiceOnce();
    final e = widget.editing;
    type = e?.type ?? widget.initialType ?? 'out';
    final major0 = e == null
        ? (widget.initialAmountIdr == null
              ? 0.0
              : CurrencyService.convert(widget.initialAmountIdr!))
        : CurrencyService.convert(e.amount);
    digits = ValueNotifier(digitsFromMajor(major0, dec: _dec));
    day = e?.date != null
        ? DateTime.tryParse(e!.date!) ?? DateTime.now()
        : DateTime.now();
    final t = txCreatedAtTime(e?.createdAt);
    useTime = t != null;
    time = t == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: t.hour, minute: t.minute);
    walletId =
        e?.walletId ?? widget.initialWalletId ?? _defaultWallet();
    toWalletId = e?.toWalletId;
    catC.text = e?.category != null
        ? parseCategory(e!.category!).top
        : (widget.initialCategory ?? '');
    subC.text = e?.category != null
        ? (parseCategory(e!.category!).sub ?? '')
        : '';
    noteC.text = e?.note ?? widget.initialNote ?? '';
    _selCat = catC.text.trim().isEmpty ? null : catC.text.trim();
    _step = _isEdit ? 1 : 0;
    // Mode chooser: picu aksi sekali setelah frame pertama.
    final mode = widget.initialMode;
    if (mode != null && !_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (mode) {
          case TxInputMode.live:
            break;
          case TxInputMode.scanManual:
            _pickScanSource();
            break;
          case TxInputMode.scanVision:
            _pickVisionSource(strict: true);
            break;
          case TxInputMode.voice:
            _toggleMic();
            break;
        }
      });
    }
  }

  /// Dompet default pengaturan (bila masih ada di daftar). Null = pilih
  /// manual / urutan Most-used seperti biasa.
  String? _defaultWallet() {
    final dw = defaultWalletId.value;
    if (dw.isEmpty) return null;
    for (final w in widget.wallets) {
      if (w.id == dw) return dw;
    }
    return null;
  }

  @override
  void dispose() {
    _quickDeb?.cancel();
    unawaited(_voice.stop());
    digits.dispose();
    quickC.dispose();
    catC.dispose();
    subC.dispose();
    noteC.dispose();
    super.dispose();
  }

  double get _idr =>
      CurrencyService.toIdr(majorFromDigits(digits.value, dec: _dec));

  /// Ketik cepat: urai teks bebas lalu prefill form (tambah saja).
  /// Tanpa nominal valid = abaikan; tak pernah menimpa saat mode edit.
  /// Simpan tetap lewat tombol (tak ada insert diam-diam).
  /// Dipanggil debounce 300 ms agar tiap karakter tak rebuild sheet.
  void _onQuickChanged(String v) {
    _quickDeb?.cancel();
    _quickDeb = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _applyQuick(v);
    });
  }

  void _applyQuick(String v) {
    if (_isEdit || v.trim().isEmpty) return;
    final q = parseQuickInput(
      v,
      categories: appCategories.value,
      wallets: [for (final w in widget.wallets) w.name],
    );
    if (q == null) {
      setState(() => _quickStatus = tr('tx_quick_no'));
      return;
    }
    setState(() {
      type = q.type;
      digits.value = digitsFromMajor(
        CurrencyService.convert(q.amount),
        dec: _dec,
      );
      if (q.category != null) catC.text = q.category!;
      if (q.walletName != null) {
        final hit = matchWalletName(
          q.walletName!,
          [for (final w in widget.wallets) w.name],
        );
        if (hit != null) {
          for (final w in widget.wallets) {
            if (w.name == hit) {
              walletId = w.id;
              break;
            }
          }
        }
      }
      noteC.text = q.note;
      final typeLabel = q.type == 'in'
          ? tr('tx_in')
          : (q.type == 'transfer' ? tr('tx_transfer') : tr('tx_out'));
      final what =
          q.category == null || q.category!.isEmpty ? q.note : q.category!;
      final idr = CurrencyService.toIdr(
        majorFromDigits(digits.value, dec: _dec),
      );
      _quickStatus = '$typeLabel · $what · ${amt(idr)}';
    });
  }

  /// Cek ketersediaan recognizer sekali (tanpa dialog, tanpa dengar).
  Future<void> _initVoiceOnce() async {
    bool ok = false;
    try {
      ok = await _voice.isAvailable();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _voiceReady = ok);
  }

  /// Mic voice input: hasil dengar ditulis ke kolom ketik-cepat lalu
  /// diparse pipeline yang sama (prefill, tanpa simpan diam-diam).
  /// Ketuk lagi = berhenti. Init sudah sekali di awal (tunggu bila
  /// belum selesai: tanpa race). Tiap kegagalan tampil di status.
  Future<void> _toggleMic() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    await _voiceInitFuture;
    if (!mounted) return;
    if (!_voiceReady) {
      setState(() => _quickStatus = tr('vc_error'));
      return;
    }
    // Recognizer sistem butuh internet (kecuali paket on-device).
    if (!netOnline.value) {
      if (mounted) setState(() => _quickStatus = tr('vc_offline'));
      return;
    }
    PermissionStatus st;
    try {
      st = await Permission.microphone.request();
    } catch (_) {
      if (mounted) setState(() => _quickStatus = tr('vc_error'));
      return;
    }
    if (!st.isGranted) {
      if (mounted) setState(() => _quickStatus = tr('vc_denied'));
      return;
    }
    // Init sudah sekali saat sheet dibuka; tinggal dengar (tanpa race).
    if (!mounted) return;
    setState(() {
      _listening = true;
      _quickStatus = tr('vc_listening');
    });
    void onVoiceResult(String words, bool finalResult) {
      if (!mounted) return;
      quickC.text = normalizeSpoken(words);
      _onQuickChanged(quickC.text);
      if (finalResult) setState(() => _listening = false);
    }

    // Default sistem dulu; id-ID sebagai retry (locale eksplisit
    // yang tak terinstall bisa menggagalkan start).
    var started = false;
    for (final attempt in voiceLocaleAttempts('id-ID')) {
      if (!mounted) break;
      started = await _voice.start(
        localeId: attempt,
        onResult: onVoiceResult,
        onError: (code) {
          _voiceErr = code;
          if (!mounted) return;
          setState(() {
            _listening = false;
            _quickStatus = tr(voiceErrorKey(code));
          });
        },
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done') {
            setState(() {
              _listening = false;
              if (quickC.text.trim().isEmpty) {
                _quickStatus = tr('vc_hear');
              }
            });
          }
        },
      );
      if (started) break;
    }
    if (!started && mounted) {
      final diag = formatMicDiagnostic(_voiceErr, null);
      setState(() {
        _listening = false;
        _quickStatus = tr('vc_error_detail').replaceFirst('{d}', diag);
      });
    }
  }

  /// Langkah 1 -> 2: kunci kategori pilihan ke field form.
  void _goStep2() {
    final c = _selCat?.trim();
    if (c == null || c.isEmpty) return;
    setState(() {
      catC.text = c;
      _step = 1;
    });
  }

  /// Dialog sumber foto lalu OCR; hasil prefill form (preview, tanpa simpan).
  Future<void> _pickScanSource() async {
    final src = await showGlassDialog<ImageSource>(
      context: context,
      title: Text(tr('rcp_scan')),
      content: Text(tr('rcp_scan_hint')),
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
      _scanErr = null;
    });
    try {
      final r = await scanReceipt(src);
      if (!mounted) return;
      final raw = lastRawOcrText;
      setState(() => _scanning = false);
      if (r == null || raw == null) return;
      var data = r;
      // Fallback AI bila rule tak confident ATAU total tak konsisten
      // dengan jumlah item (hybrid, gagal = manual).
      final inconsistent = itemsMismatch(
        [for (final li in r.lineItems) li.price],
        r.amount,
      );
      if (!data.confident || inconsistent) {
        final ai = await _tryAiDraft(raw);
        if (!mounted) return;
        if (ai != null) {
          final edited = await Navigator.of(context).push<ReceiptData>(
            MaterialPageRoute(builder: (_) => AiDraftScreen(initial: ai)),
          );
          if (!mounted) return;
          if (edited != null) data = edited;
        }
      }
      if (!mounted) return;
      _applyReceiptPrefill(data);
      if (mounted) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => GlassSheetScaffold(
            child: ReceiptResultSheet(
              data: data,
              mirror: mirrorReceipt(
                raw,
                pairOrphans: layoutFor(detectReceiptKind(raw)).pairOrphans,
              ),
              onShowRaw: () => _showRawOcrDialog(raw),
            ),
          ),
        );
      }
    } on ReceiptScanException catch (e) {
      if (!mounted) return;
      final raw = lastRawOcrText;
      setState(() {
        _scanning = false;
        _scanErr = e.detail == null
            ? tr(e.trKey)
            : '${tr(e.trKey)}\n${e.detail}';
      });
      if (raw != null) await _showRawOcrDialog(raw);
    }
  }

  /// Scan AI: foto -> model vision LANGSUNG tanpa OCR. Hasil prefill
  /// + replika; baris dibangun dari item (bisa edit penuh di form).
  Future<void> _pickVisionSource({bool strict = false}) async {
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
      _scanErr = null;
    });
    try {
      final out = await scanReceiptVision(src, strictVision: strict);
      if (!mounted) return;
      setState(() => _scanning = false);
      if (out == null) return;
      _applyReceiptPrefill(out.data, aiCategory: out.category);
      setState(() {
        _scanOrigin = '${out.provider} · ${_scanOrigin ?? ''}';
      });
      if (mounted) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => ReceiptResultSheet(
            data: out.data,
            mirror: _visionMirror(out.data),
            onShowRaw: () => _showRawOcrDialog(out.data.merchant ?? ''),
          ),
        );
      }
    } on VisionScanException catch (e) {
      if (!mounted) return;
      // Kuota AI mentok (dilempar scanReceiptVision sebelum model
      // dipanggil) -> paywall Pro, bukan error struk.
      if (e.trKey == 'q_ai_exceeded') {
        setState(() => _scanning = false);
        await requirePro(context, tr('q_ai_exceeded'));
        return;
      }
      setState(() {
        _scanning = false;
        _scanErr = e.detail == null
            ? tr(e.trKey)
            : '${tr(e.trKey)}\n${e.detail}';
      });
    } on AiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanErr = e.code == 'quota'
            ? quotaWaitLine(e.detail)
            : tr(aiMessageKey(e.code));
      });
    }
  }

  /// Replika baris dari item vision (tanpa OCR): merchant + item + total.
  List<MirrorLine> _visionMirror(ReceiptData r) {
    final lines = <MirrorLine>[];
    if ((r.merchant ?? '').trim().isNotEmpty) {
      lines.add(MirrorLine(r.merchant!.trim(), centered: true, bold: true));
    }
    for (final it in r.lineItems) {
      final qty = it.qty > 1 ? ' x${it.qty}' : '';
      lines.add(MirrorLine('${it.name}$qty', amount: it.price * it.qty));
    }
    if (r.amount != null && r.amount! > 0) {
      lines.add(MirrorLine(tr('rcp_total'), amount: r.amount, bold: true));
    }
    return lines;
  }

  /// Prefill form dari hasil struk (rule maupun draft AI yang diedit).
  /// [aiCategory]: kategori dari AI scan struk (sudah divalidasi ketat);
  /// bila ada, dipakai langsung tanpa saran heuristik.
  void _applyReceiptPrefill(ReceiptData r, {String? aiCategory}) {
    setState(() {
      if (r.amount != null && r.amount! > 0) {
        type = 'out';
        digits.value = digitsFromMajor(
          CurrencyService.convert(r.amount!),
          dec: _dec,
        );
      }
      if (r.date != null) day = r.date!;
      // Vision: simpan detail struk lengkap sebagai catatan (terlihat utuh
      // di detail transaksi). OCR/rule: ringkasan seperti sebelumnya.
      final dt = r.detailText;
      noteC.text = (dt != null && dt.trim().isNotEmpty) ? dt : receiptNote(r);
      if (_selCat == null || _selCat!.trim().isEmpty) {
        final cats = appCategories.value;
        _selCat = cats.contains('Belanja')
            ? 'Belanja'
            : (cats.isEmpty ? 'Belanja' : cats.first);
      }
      catC.text = _selCat!.trim();
      final aiCat = aiCategory?.trim();
      final cats2 = appCategories.value;
      if (aiCat != null &&
          aiCat.isNotEmpty &&
          cats2.any((c) => c.trim().toLowerCase() == aiCat.toLowerCase())) {
        _selCat = cats2
            .firstWhere((c) => c.trim().toLowerCase() == aiCat.toLowerCase())
            .trim();
        catC.text = _selCat!.trim();
      } else {
        final sug = suggestReceiptCategory(
          merchant: r.merchant,
          items: r.items,
          raw: lastRawOcrText,
          categories: appCategories.value,
        );
        if (sug != null) {
          _selCat = sug;
          catC.text = sug;
        }
      }
      _scanOrigin = _scanOriginText(r);
      if (!r.confident) formErr = tr('rcp_partial');
      _step = 1;
    });
  }

  /// AI fallback untuk scan struk berbasis aturan.
  ///
  /// DINONAKTIFKAN 2026-10-15: jalur ini memanggil Zen API langsung yang
  /// free tier-nya 403 ("can only be used from within OpenCode").
  /// Pengganti: scan vision via OpenCode lokal (_pickVisionSource).
  /// null = isi manual (jujur, tanpa fallback diam-diam).
  ///
  /// AI gate intentionally absent: stub returns null, no AI consumed.
  Future<AiDraft?> _tryAiDraft(String raw) async {
    // AI gate intentionally absent: stub returns null, no AI consumed.
    return null;
  }

  /// Ringkasan asal prefill struk: nominal + tanggal + kategori.
  String _scanOriginText(ReceiptData r) {
    final parts = <String>[tr('rcp_origin_from')];
    if (r.amount != null && r.amount! > 0) {
      parts.add(
        amt(CurrencyService.toIdr(CurrencyService.convert(r.amount!))),
      );
    }
    if (r.date != null) parts.add(dayLabel(txYmd(r.date!)));
    final cat = catC.text.trim();
    parts.add(cat.isEmpty ? _kindOrMerchant(r) : cat);
    return parts.join(' · ');
  }

  /// Merchant bila ada, kalau tidak label jenis struk.
  String _kindOrMerchant(ReceiptData r) {
    if ((r.merchant ?? '').trim().isNotEmpty) return r.merchant!.trim();
    switch (detectReceiptKind(lastRawOcrText ?? '')) {
      case ReceiptDocKind.minimarket:
        return tr('rcp_kind_mini');
      case ReceiptDocKind.dining:
        return tr('rcp_kind_food');
      case ReceiptDocKind.fuel:
      case ReceiptDocKind.pharmacy:
      case ReceiptDocKind.generic:
        return tr('rcp_scan');
    }
  }

  /// Diagnosis scan: tampilkan teks OCR mentah agar bisa di-screenshot
  /// dan dilapor. Hanya di layar, tak diupload ke mana pun.
  Future<void> _showRawOcrDialog(String raw) async {
    final ocr = raw.trim().isEmpty ? tr('rcp_raw_empty') : raw;
    final err = _aiErrDetail;
    final body = err == null ? ocr : '$err\n\n---\n\n$ocr';
    await showGlassDialog<void>(
      context: context,
      title: Text(tr('rcp_raw_title')),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: SelectableText(body),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('rcp_raw_close')),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => day = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: time);
    if (picked != null) setState(() => time = picked);
  }

  Future<void> _save() async {
    final invalid = validateTxField(
      amount: _idr,
      walletId: walletId,
      type: type,
      toWalletId: toWalletId,
    );
    if (invalid != null) {
      setState(() {
        amountErr = invalid == TxInvalid.amount ? tr('txv_amount') : null;
        walletErr = invalid == TxInvalid.wallet ? tr('txv_wallet') : null;
        toWalletErr = switch (invalid) {
          TxInvalid.toWallet => tr('txv_towallet'),
          TxInvalid.sameWallet => tr('txv_same'),
          _ => null,
        };
      });
      return;
    }
    setState(() {
      saving = true;
      formErr = null;
      amountErr = null;
      walletErr = null;
      toWalletErr = null;
    });
    try {
      final when = txWhen(
        day,
        hour: useTime ? time.hour : null,
        minute: useTime ? time.minute : null,
      );
      final top = catC.text.trim();
      final sub = subC.text.trim();
      if (sub.contains('>') || top.contains('>')) {
        if (!mounted) return;
        setState(() {
          saving = false;
          formErr = tr('sub_sep_err');
        });
        return;
      }
      final cat = top.isEmpty
          ? null
          : (sub.isEmpty ? top : formatCategory(top, sub));
      final note = noteC.text.trim();
      final svc = TransactionService();
      if (_isEdit) {
        await svc.update(
          id: widget.editing!.id,
          orgId: widget.orgId,
          type: type,
          amount: _idr,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note.isEmpty ? null : note,
          date: when.date,
          createdAt: when.createdAt,
        );
      } else {
        await svc.add(
          orgId: widget.orgId,
          type: type,
          amount: _idr,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note,
          date: when.date,
          createdAt: when.createdAt,
        );
      }
      try {
        if (walletId != null) await noteWalletUsed(walletId!);
        if (type == 'transfer' && toWalletId != null) {
          await noteWalletUsed(toWalletId!);
        }
      } catch (_) {}
      // Alert budget baru (bila tembus): idempoten, fail-silent.
      unawaited(BudgetAlertNotify.check(widget.orgId));
      // Snapshot + refresh widget home: fail-silent.
      unawaited(refreshBudgetWidgetSnapshot(widget.orgId).catchError((_) {}));
      if (!mounted) return;
      Navigator.pop(context, 'saved');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        formErr = _txError(e);
      });
    }
  }

  String _txError(Object e) {
    // Mode bendahara: pesan jujur dari service (bukan error teknis).
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

  /// Hapus langsung (dipanggil SwipeToConfirmButton — geser = setuju,
  /// tanpa dialog lagi). Keputusan user TAHAP 4e.
  Future<void> _deleteDirect() async {
    try {
      await TransactionService().delete(widget.editing!.id, widget.orgId);
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    } catch (e) {
      if (!mounted) return;
      setState(() => formErr = _txError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
        padding: EdgeInsets.only(
          left: SsrSpace.lg,
          right: SsrSpace.lg,
          top: SsrSpace.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + SsrSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DragHandle(),
            _SheetHeader(
              isEdit: _isEdit,
              title: _isEdit
                  ? null
                  : (_step == 0 ? tr('wiz_step1') : tr('wiz_step2')),
              code: widget.editing?.code,
              onClose: () => Navigator.pop(context),
            ),
            if (_step == 0 && !_isEdit) ...[
              const SizedBox(height: SsrSpace.sm),
              TxTypeSelector(
                value: type,
                onChanged: (v) => setState(() => type = v),
              ),
              const SizedBox(height: SsrSpace.md),
              _CategoryGrid(
                selected: _selCat,
                onPick: (c) => setState(() => _selCat = c),
              ),
              const SizedBox(height: SsrSpace.md),
              _ScanRow(
                scanning: _scanning,
                error: _scanErr,
                onScan: _scanning ? null : _pickScanSource,
                onScanVision:
                    _scanning ? null : () => _pickVisionSource(strict: true),
              ),
              const SizedBox(height: SsrSpace.md),
              PremiumButton(
                label: tr('wiz_next'),
                onPressed: _selCat == null ? null : _goStep2,
              ),
            ] else ...[
              _TypeCatRow(
                type: type,
                category: catC.text,
              ),
              if (!_isEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _step = 0),
                    child: Text('‹ ${tr('wiz_back')}'),
                  ),
                ),
              if (!_isEdit) ...[
                const SizedBox(height: SsrSpace.sm),
                _QuickSection(
                  controller: quickC,
                  onChanged: _onQuickChanged,
                  status: _quickStatus,
                  onMic: _toggleMic,
                  listening: _listening,
                ),
              ],
              if (_scanOrigin != null) ...[
                const SizedBox(height: SsrSpace.sm),
                _ScanOriginBanner(text: _scanOrigin!),
              ],
              _AmountDisplay(
                digits: digits,
                dec: _dec,
                error: amountErr,
              ),
              const SizedBox(height: SsrSpace.sm),
            TxNumpad(digits: digits),
            const SizedBox(height: SsrSpace.sm),
            _DateTimeSection(
              day: day,
              useTime: useTime,
              time: time,
              onPickDate: _pickDate,
              onToggleTime: (v) => setState(() => useTime = v),
              onPickTime: _pickTime,
            ),
            _WalletSection(
              type: type,
              walletId: walletId,
              toWalletId: toWalletId,
              wallets: widget.wallets,
              balances: widget.balances,
              walletErr: walletErr,
              toWalletErr: toWalletErr,
              onWalletChanged: (v) => setState(() {
                walletId = v;
                walletErr = null;
              }),
              onToWalletChanged: (v) => setState(() {
                toWalletId = v;
                toWalletErr = null;
              }),
            ),
            _MetaSection(
              catC: catC,
              subC: subC,
              noteC: noteC,
              selected: catC.text,
              onPick: (c) => setState(() {
                catC.text = c;
                _selCat = c;
              }),
              showSub: _showSub,
              onShowSub: () => setState(() => _showSub = true),
            ),
            if (formErr != null) ...[
              const SizedBox(height: SsrSpace.sm),
              Text(
                formErr!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: SsrSpace.md),
            PremiumButton(
              label: _isEdit ? tr('tx_save_edit') : tr('tx_save_add'),
              onPressed: _save,
              loading: saving,
              gradient: const LinearGradient(
                colors: [DribTokens.primary, DribTokens.primary],
              ),
              foreground: DribTokens.navy,
            ),
            if (_isEdit) ...[
              const SizedBox(height: SsrSpace.sm),
              SwipeToConfirmButton(
                label: tr('tx_delete'),
                onConfirm: _deleteDirect,
              ),
            ],
          ],
        ],
        ),
      ),
        if (_scanning) const ScanOverlay(),
        ],
      ),
    );
  }
}

/// Gagang drag sheet (motif ledger: garis pendek di tengah).
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
        decoration: BoxDecoration(
          color: scheme.outline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Judul sheet + tombol tutup. Mode edit menampilkan kode TX.
/// [title] menimpa judul bawaan (dipakai langkah 1 wizard).
class _SheetHeader extends StatelessWidget {
  final bool isEdit;
  final String? title;
  final String? code;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.isEdit,
    this.title,
    required this.code,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? (isEdit ? tr('tx_form_edit') : tr('tx_form_add')),
                style: theme.textTheme.titleMedium,
              ),
              if (isEdit && code != null)
                Text(
                  code!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const DuoIcon(AppIcons.close),
          tooltip: tr('back'),
        ),
      ],
    );
  }
}

/// Langkah 1 wizard: grid kategori 2 kolom dengan ikon ledger.
/// Sel seragam karena pilihan setara (bukan hierarki).
class _CategoryGrid extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onPick;

  const _CategoryGrid({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: appCategories,
      builder: (_, cats, __) {
        if (cats.isEmpty) return const SizedBox.shrink();
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: SsrSpace.sm,
          crossAxisSpacing: SsrSpace.sm,
          childAspectRatio: 3.4,
          children: [
            for (final c in cats)
              _CatCell(
                label: c,
                selected: c == selected,
                onTap: () => onPick(c),
              ),
          ],
        );
      },
    );
  }
}

/// Satu sel kategori: ikon ledger + label, min 44px ikut grid.
class _CatCell extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CatCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final fg = selected
        ? scheme.primary
        : theme.textTheme.bodyMedium?.color ?? scheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(SsrRadius.tile),
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: SsrSpace.md),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.08)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(SsrRadius.tile),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: DribTokens.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: SvgPicture.asset(
                  svgForCategory(label),
                  width: 20,
                  colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: SsrSpace.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section AI struk: kartu sendiri yang lega — judul + tombol scan
/// besar + status terbaca. M3: container tonal, sudut 16, spacing lega.
class _ScanRow extends StatelessWidget {
  final bool scanning;
  final String? error;
  final VoidCallback? onScan;
  final VoidCallback? onScanVision;

  const _ScanRow({
    required this.scanning,
    required this.error,
    required this.onScan,
    this.onScanVision,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(SsrSpace.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DuoIcon(AppIcons.scan, size: 22, color: scheme.primary),
              const SizedBox(width: SsrSpace.sm),
              Expanded(
                child: Text(
                  tr('ai_scan_title'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            tr('rcp_scan_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SsrSpace.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onScan,
                  icon: const DuoIcon(AppIcons.scan, size: 20),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error != null ? tr('ai_rescan') : tr('scan_mode_ocr')),
                        Text(
                          tr('scan_mode_ocr_s'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SsrSpace.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onScanVision,
                  icon: const DuoIcon(AppIcons.autoBadge, size: 20),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr('scan_mode_vision')),
                        Text(
                          tr('scan_mode_vision_s'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (scanning) ...[
            const SizedBox(height: SsrSpace.md),
            const LinearProgressIndicator(),
            const SizedBox(height: SsrSpace.sm),
            Text(
              tr('rcp_scanning'),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: SsrSpace.md),
            Text(
              error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Ringkasan pilihan langkah 1 di atas form.
class _TypeCatRow extends StatelessWidget {
  final String type;
  final String category;

  const _TypeCatRow({
    required this.type,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = type == 'in'
        ? tr('tx_in')
        : (type == 'transfer' ? tr('tx_transfer') : tr('tx_out'));
    return Row(
      children: [
        Expanded(
          child: Text(
            category.trim().isEmpty
                ? typeLabel
                : '$typeLabel · ${category.trim()}',
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Ketik cepat: satu baris teks bebas yang diparse live menjadi prefill.
/// Murni jalan pintas pengisi; validasi + simpan tetap lewat alur biasa.
class _QuickSection extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? status;
  final VoidCallback onMic;
  final bool listening;

  const _QuickSection({
    required this.controller,
    required this.onChanged,
    this.status,
    required this.onMic,
    required this.listening,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: tr('tx_quick_hint'),
            prefixIcon: const DuoIcon(AppIcons.search, size: 20),
            suffixIcon: IconButton(
              icon: DuoIcon(
                AppIcons.voice,
                size: 22,
                color: listening ? theme.colorScheme.primary : null,
              ),
              tooltip: tr('vc_mic'),
              onPressed: onMic,
            ),
          ),
        ),
        if (status != null) ...[
          const SizedBox(height: SsrSpace.xs),
          Text(
            status!,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Asal prefill struk: nominal + tanggal + kategori yang terisi.
class _ScanOriginBanner extends StatelessWidget {
  final String text;

  const _ScanOriginBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SsrSpace.md,
        vertical: SsrSpace.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SsrRadius.tile),
      ),
      child: Row(
        children: [
          DuoIcon(AppIcons.scan, size: 16, color: scheme.primary),
          const SizedBox(width: SsrSpace.sm),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Display nominal besar: ikut tiap ketukan numpad, format mata uang aktif.
class _AmountDisplay extends StatelessWidget {
  final ValueNotifier<String> digits;
  final int dec;
  final String? error;

  const _AmountDisplay({
    required this.digits,
    required this.dec,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.md),
      child: Column(
        children: [
          Text(
            tr('tx_f_nominal'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: SsrSpace.sm),
          ValueListenableBuilder<String>(
            valueListenable: digits,
            builder: (_, d, __) {
              final idr =
                  CurrencyService.toIdr(majorFromDigits(d, dec: dec));
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: DribTokens.balanceGradient,
                  borderRadius: BorderRadius.circular(
                      DribTokens.cardRadius),
                  boxShadow: DribTokens.cardShadow,
                ),
                child: Text(
                  CurrencyService.format(idr),
                  style: DribTokens.bigNumber(
                      size: 32, color: DribTokens.onNavy),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}

/// Baris tanggal (selalu ada, default hari ini) + switch jam opsional.
class _DateTimeSection extends StatelessWidget {
  final DateTime day;
  final bool useTime;
  final TimeOfDay time;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onToggleTime;
  final VoidCallback onPickTime;

  const _DateTimeSection({
    required this.day,
    required this.useTime,
    required this.time,
    required this.onPickDate,
    required this.onToggleTime,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('tx_f_date'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onPickDate,
              icon: const DuoIcon(AppIcons.calendar, size: 18),
              label: Text(dayLabel(txYmd(day))),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                tr('tx_add_time'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Switch(value: useTime, onChanged: onToggleTime),
            if (useTime)
              OutlinedButton.icon(
                onPressed: onPickTime,
                icon: const DuoIcon(AppIcons.clock, size: 18),
                label: Text(
                  '${time.hour.toString().padLeft(2, '0')}:'
                  '${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
        Text(
          tr('tx_date_hint'),
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Dropdown dompet (+ tujuan saat transfer), label ikut saldo mask-aware.
class _WalletSection extends StatelessWidget {
  final String type;
  final String? walletId;
  final String? toWalletId;
  final List<Wallet> wallets;
  final Map<String, double> balances;
  final String? walletErr;
  final String? toWalletErr;
  final ValueChanged<String?> onWalletChanged;
  final ValueChanged<String?> onToWalletChanged;

  const _WalletSection({
    required this.type,
    required this.walletId,
    required this.toWalletId,
    required this.wallets,
    required this.balances,
    this.walletErr,
    this.toWalletErr,
    required this.onWalletChanged,
    required this.onToWalletChanged,
  });

  DropdownMenuItem<String> _item(Wallet w, ThemeData theme) {
    final bal = balances[w.id];
    final muted = theme.textTheme.bodySmall?.color;
    return DropdownMenuItem(
      value: w.id,
      child: Text(
        bal == null ? w.name : '${w.name} · ${amt(bal)}',
        style: bal == null
            ? null
            : theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: walletUseCounts,
      builder: (_, counts, __) {
        final names = <String, String>{
          for (final w in wallets) w.id: w.name,
        };
        final byId = <String, Wallet>{for (final w in wallets) w.id: w};
        final ordered = [
          for (final id in sortIdsByUse(counts, names)) byId[id]!,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: SsrSpace.sm),
            DropdownButtonFormField<String>(
              initialValue: walletId,
              decoration: InputDecoration(
                labelText: tr('tx_f_wallet'),
                errorText: walletErr,
              ),
              items: [for (final w in ordered) _item(w, theme)],
              onChanged: onWalletChanged,
            ),
            if (type == 'transfer') ...[
              const SizedBox(height: SsrSpace.md),
              DropdownButtonFormField<String>(
                initialValue: toWalletId,
                decoration: InputDecoration(
                  labelText: tr('tx_f_towallet'),
                  helperText: tr('tx_towallet_help'),
                  errorText: toWalletErr,
                ),
                items: [for (final w in ordered) _item(w, theme)],
                onChanged: onToWalletChanged,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Kategori (field + chip pintasan), subkategori opsional, dan catatan.
class _MetaSection extends StatelessWidget {
  final TextEditingController catC;
  final TextEditingController subC;
  final TextEditingController noteC;
  final String selected;
  final ValueChanged<String> onPick;
  final bool showSub;
  final VoidCallback onShowSub;

  const _MetaSection({
    required this.catC,
    required this.subC,
    required this.noteC,
    required this.selected,
    required this.onPick,
    required this.showSub,
    required this.onShowSub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: SsrSpace.md),
        TextField(
          controller: catC,
          decoration: InputDecoration(labelText: tr('tx_f_cat')),
        ),
        const SizedBox(height: SsrSpace.sm),
        CategoryChips(
          controller: catC,
          selected: selected,
          onPick: onPick,
        ),
        const SizedBox(height: SsrSpace.sm),
        if (showSub)
          TextField(
            controller: subC,
            decoration: InputDecoration(labelText: tr('sub_hint')),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onShowSub,
              child: Text(tr('sub_add')),
            ),
          ),
        const SizedBox(height: SsrSpace.md),
        TextField(
          controller: noteC,
          decoration: InputDecoration(
            labelText: tr('tx_f_note'),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: noteC,
              builder: (_, v, __) => IconButton(
                onPressed: v.text.trim().isEmpty
                    ? null
                    : () => showNoteDialog(context, v.text.trim()),
                icon: const DuoIcon(AppIcons.eye),
                tooltip: tr('tx_f_note'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
