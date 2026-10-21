import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:ssr_space/services/ai_context.dart';
import 'package:ssr_space/services/ai_assistant_context.dart';
import 'package:ssr_space/services/ai_correction.dart';
import 'package:ssr_space/services/ai_key_store.dart';
import 'package:ssr_space/services/ai_memory.dart';
import 'package:ssr_space/services/ai_merchant_alias.dart';
import 'package:ssr_space/services/ai_persona.dart';
import 'package:ssr_space/services/ai_chat_parse.dart';
import 'package:ssr_space/services/ai_soul.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/quick_input_parse.dart';
import 'package:ssr_space/services/recurring_bills.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/tx_input_logic.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/ai_zen_client.dart';
import 'package:ssr_space/services/ai_quota.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';
import 'package:ssr_space/screens/budget/budgets_screen.dart';
import 'package:ssr_space/screens/dompet/wallets_screen.dart';
import 'package:ssr_space/screens/lainnya/billing_screen.dart';
import 'package:ssr_space/screens/lainnya/categories_screen.dart';
import 'package:ssr_space/screens/lainnya/nfc_cards_screen.dart';
import 'package:ssr_space/screens/lainnya/recurring_bills_screen.dart';
import 'package:ssr_space/screens/lainnya/settings_screen.dart';
import 'package:ssr_space/screens/laporan/reports_screen.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/tx_input_sheet.dart';

/// Room chat AI: tanya apa saja (+ lampiran gambar), jawab via provider
/// aktif. Riwayat chat tersimpan di HP sampai user menghapusnya via
/// menu "Mulai percakapan baru". Fakta ```ingat``` + ringkasan
/// ```ringkas``` tersimpan otomatis ke Memori AI (bisa diubah user);
/// aksi ```tx``` tampil kartu [Jalankan] -> form prefill (user simpan).
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _ChatMsg {
  final bool mine;
  final String text;
  final String? provider;
  final bool isError;
  final List<int>? image;
  final TxDraft? action;
  final BillDraft? billAction;
  final BudgetDraft? budgetAction;
  /// Aksi ditolak validasi tapi reply janji konfirmasi -> kartu perbaikan.
  final PendingChatAction? pendingAction;

  /// Perintah non-transaksi tervalidasi (navigate dst., batch 281).
  final Map<String, dynamic>? command;

  /// Mode asal pesan: 'catat' | 'asisten' (batch 281C). Riwayat dan
  /// konteks yang dikirim ke model dipisah per mode.
  final String mode;

  /// Blok viz tervalidasi dari model (Mode Asisten, tahap 281C-2).
  final Map<String, dynamic>? viz;

  /// Snapshot lokal saat pesan dibuat: sumber angka kartu viz.
  final AssistantSnapshot? vizData;
  const _ChatMsg({
    required this.mine,
    required this.text,
    this.provider,
    this.isError = false,
    this.image,
    this.action,
    this.billAction,
    this.budgetAction,
    this.pendingAction,
    this.command,
    this.mode = 'catat',
    this.viz,
    this.vizData,
  });

  bool get hasAction =>
      action != null || billAction != null || budgetAction != null;
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _items = <_ChatMsg>[];
  final _c = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  List<int>? _pendingImage;
  String? _pendingMime;
  String _lastUserText = '';
  String _dataCtx = '';
  String _providerId = 'server';

  /// Mode chat aktif: 'catat' (parser transaksi, perilaku asli) atau
  /// 'asisten' (analis ala Ollo, batch 281C).
  String _mode = 'catat';
  static const _kMode = 'ai_chat_mode';

  /// Pesan yang tampil & jadi konteks: hanya mode aktif.
  List<_ChatMsg> get _visibleItems =>
      [for (final m in _items) if (m.mode == _mode) m];

  Future<void> _loadMode() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getString(_kMode) == 'asisten' && mounted) {
        setState(() => _mode = 'asisten');
      }
    } catch (_) {}
  }

  void _setMode(String m) {
    if (m == _mode || _sending) return;
    setState(() => _mode = m);
    unawaited(() async {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kMode, m);
      } catch (_) {}
    }());
    _toBottom();
  }

  /// Transaksi terakhir yang berhasil dicatat lewat chat pada sesi ini
  /// (referensi untuk action edit_last/delete_last, batch 281).
  SaasTransaction? _lastChatTx;
  int _animFrom = 0;

  /// Kunci prefs arsip riwayat chat (teks saja, maks 50 pesan terakhir).
  /// Session TIDAK dihapus saat keluar room; hanya dihapus lewat menu
  /// "Mulai percakapan baru".
  static const _kSession = 'ai_chat_session';
  static const _kSessionCap = 50;

  /// Simpan riwayat chat (teks saja) ke prefs. Kartu aksi tidak
  /// dipulihkan (arsip teks percakapan saja). Tanpa simpan otomatis
  /// ke database transaksi — ini arsip lokal percakapan.
  Future<void> _saveSession() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = _items.take(_kSessionCap).map((m) => {
            'mine': m.mine,
            'text': m.text,
            'provider': m.provider,
            'err': m.isError,
            'mode': m.mode,
          }).toList();
      await p.setString(_kSession, jsonEncode(list));
    } catch (_) {}
  }

  /// Pulihkan riwayat chat terakhir saat room dibuka.
  Future<void> _loadSession() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kSession);
      if (raw == null || raw.isEmpty) return;
      final d = jsonDecode(raw);
      if (d is! List) return;
      final restored = <_ChatMsg>[];
      for (final e in d.take(_kSessionCap)) {
        if (e is! Map) continue;
        final t = e['text'];
        if (t is! String || t.isEmpty) continue;
        restored.add(_ChatMsg(
          mine: e['mine'] == true,
          text: t,
          provider: e['provider'] as String?,
          isError: e['err'] == true,
          mode: (e['mode'] as String?) ?? 'catat',
        ));
      }
      if (restored.isNotEmpty && mounted) {
        setState(() => _items.addAll(restored));
        _toBottom();
      }
    } catch (_) {}
  }

  /// Hapus arsip riwayat chat (dipanggil dari "Mulai percakapan baru").
  Future<void> _clearSession() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kSession);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskData());
    aiProviderId().then((v) {
      if (mounted) setState(() => _providerId = v);
    });
    // Pulihkan riwayat chat terakhir (tidak dihapus saat keluar room).
    _loadSession();
    _loadMode();
  }

  /// Izin akses data sekali (awal penggunaan): ya = AI baca snapshot
  /// data; tidak = chat polos. Pilihan tersimpan.
  Future<void> _maybeAskData() async {
    if (!mounted) return;
    bool? choice;
    try {
      choice = await aiDataChoice();
    } catch (_) {
      return;
    }
    if (!mounted || choice != null) {
      if (choice == true) _dataCtx = await buildAiDataContext();
      return;
    }
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr('ai_data_t')),
        content: Text(tr('ai_data_s')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('ai_deny')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('ai_allow')),
          ),
        ],
      ),
    );
    await setAiDataChoice(allow == true);
    if (!mounted) return;
    if (allow == true) _dataCtx = await buildAiDataContext();
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Pesan error sesuai penyebab nyata (jangan semua "sibuk").
  /// Detail dari native tak memuat kunci/data user (mask di hulu).
  String _friendly(AiFailure e) {
    if (e.code == 'quota') return quotaWaitLine(e.detail);
    final d = e.detail ?? '';
    if (d.startsWith('[Gambar]')) return d;
    final low = d.toLowerCase();
    // Pesan server yang sudah utuh untuk user (kuota habis dari Edge
    // Function / sesi berakhir): tampilkan apa adanya.
    if (low.contains('kuota ai bulan ini habis') ||
        low.contains('sesi login berakhir')) {
      return d.replaceFirst('[AI] ', '');
    }
    // Server Mang AI bermasalah / gateway tak terjangkau.
    if (low.contains('ai gateway') ||
        low.contains('ai_upstream') ||
        low.contains('server ai') ||
        low.contains('opencode serve') ||
        low.contains('connection refused') ||
        low.contains('failed to connect') ||
        low.contains('127.0.0.1') ||
        low.contains('localhost')) {
      return tr('ai_err_server');
    }
    // Timeout (Dart) maupun timeout native.
    if (e.code == 'timeout' || low.contains('timeout')) {
      return tr('ai_err_timeout');
    }
    if (e.code == 'denied') return tr('ai_key_invalid');
    // Respons kosong / tak valid dari model.
    if (low.contains('response kosong') ||
        low.contains('tidak mengembalikan teks')) {
      return tr('ai_err_bad_response');
    }
    // Limit provider.
    if (low.contains('limit terlampaui')) {
      return tr('ai_err_rate_limit');
    }
    if (e.code == 'empty') return tr('ai_fail');
    // Error server lain (gateway/upstream) -> pesan server generik.
    if (e.code == 'server') return tr('ai_err_server');
    // Selain itu: model benar-benar sibuk.
    return tr('ai_busy');
  }

  Future<void> _pickImage() async {
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600, // NICE-TO-HAVE #N8: batasi tinggi juga (anti OOM foto portrait)
        imageQuality: 85,
      );
      if (shot == null || !mounted) return;
      final bytes = await File(shot.path).readAsBytes();
      if (!mounted || bytes.isEmpty) return;
      setState(() {
        _pendingImage = bytes;
        _pendingMime = shot.path.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
      });
    } catch (_) {}
  }

  Future<void> _send([String? retryText]) async {
    final text = (retryText ?? _c.text).trim();
    final img = retryText != null ? null : _pendingImage;
    final mime = retryText != null ? null : _pendingMime;
    if ((text.isEmpty && img == null) || _sending) return;
    _lastUserText = text;
    // Gate kuota AI (entitlement Fase 1): tiap kirim dicek. Mentok ->
    // paywall + batal (tanpa panggil model, tanpa bubble user baru).
    // Fail-open: server diam -> lolos (aiAllowed true).
    final orgId = await activeOrgId();
    if (orgId.isNotEmpty && !await aiAllowed(orgId)) {
      if (!mounted) return;
      await requirePro(context, tr('q_ai_exceeded'));
      return;
    }
    final memory = await loadAiMemory();
    if (!mounted) return;
    final summaries = await loadAiSummaries();
    if (!mounted) return;
    final persona = await loadAiPersona();
    if (!mounted) return;
    // Mode Asisten: rakit snapshot terstruktur (konteks model + sumber
    // angka viz). Hanya bila user mengizinkan akses data (_dataCtx
    // terisi); tanpa izin, asisten menjawab tanpa konteks/viz.
    AssistantSnapshot? snap;
    String? asistenCtx;
    if (_mode == 'asisten' && _dataCtx.isNotEmpty) {
      snap = await buildAssistantSnapshot();
      if (!mounted) return;
      final t = assistantContextText(snap);
      if (t.isNotEmpty) asistenCtx = t;
    }
    final asisten = _mode == 'asisten';
    final pBlock = aiPersonaBlock(persona);
    final ctxBlock = asisten
        ? aiAssistantContextBlock(memory, summaries, pBlock)
        : aiContextBlock(memory, summaries, pBlock);
    // Batch 281D tahap 2: hint alias merchant (Mode Catat saja) —
    // kebiasaan user (merchant -> kategori/dompet) disuntikkan
    // sebagai petunjuk kuat ke prompt. Fail-open; Mode Asisten
    // tidak berubah.
    var aliasHint = '';
    if (!asisten && text.isNotEmpty) {
      try {
        final aliases = await loadMerchantAliases();
        final aliasHit = findAliasFor(text, aliases);
        if (aliasHit != null) aliasHint = '\n${aliasHintBlock(aliasHit)}';
      } catch (_) {}
    }
    final prompt = text.isEmpty
        ? '$ctxBlock\nJelaskan gambar terlampir.'
        : '$ctxBlock$aliasHint\nUser: $text';
    setState(() {
      _animFrom = _visibleItems.length;
      _items.add(_ChatMsg(
          mine: true,
          text: text.isEmpty ? '(gambar)' : text,
          image: img,
          mode: _mode));
      _c.clear();
      _pendingImage = null;
      _pendingMime = null;
      _sending = true;
    });
    unawaited(_saveSession());
    _toBottom();
    // Riwayat sesi sebagai konteks (16 turn terakhir + digest lama).
    final history = [
      for (final m in _items)
        if (m.mode == _mode)
          (mine: m.mine, text: m.image != null ? '${m.text} [gambar]' : m.text),
    ];
    try {
      final r = await aiChat(prompt,
          imageBytes: img,
          mimeType: mime,
          history: history,
          dataContext:
              asisten ? asistenCtx : (_dataCtx.isEmpty ? null : _dataCtx),
          system: asisten ? '$aiAssistantSoul $aiAssistantVizHint' : null);
      // Sukses -> catat pemakaian kuota AI (fail-silent, tanpa blokir UI).
      if (orgId.isNotEmpty) unawaited(recordAiUse(orgId, 'chat'));
      if (!mounted) return;
      unawaited(
          addAiMemory(parseIngatBlocks(r.text)).then((_) async {
        final n = await loadAiMemory();
        debugPrint('ai memori: ${n.length} fakta');
      }));
      // Memori.md dalam app: simpan ringkasan percakapan penting.
      // Hanya jumlah yang di-log, bukan isi ringkasan.
      unawaited(addAiSummary(parseRingkasBlocks(r.text)).then((_) async {
        final n = await loadAiSummaries();
        debugPrint('ai memori: ${n.length} ringkasan');
      }));
      // Kontrak JSON baru: ekstrak reply + action tervalidasi.
      // Blok ```ingat```/```ringkas``` (memori) dibuang dulu dari teks
      // yang di-parse agar jsonDecode tidak gagal; fitur ingat+ringkas
      // tetap jalan dari r.text mentah pada addAiMemory/addAiSummary.
      final walletNames = await _walletNames();
      final parsed = parseChatReply(
        stripRingkasBlocks(stripIngatBlocks(r.text)),
        wallets: walletNames,
        categories: appCategories.value,
      );
      // Debug-only: kode alasan penolakan aksi (tanpa isi pesan/nominal).
      debugPrint('ai_action: ${parsed.reason ?? 'ok'}');
      // Fallback: aksi ditolak tapi reply janji konfirmasi -> kartu
      // perbaikan (jangan buang diam-diam). Tanpa simpan otomatis.
      PendingChatAction? pending;
      final rawType = parsed.actionRaw?['type'];
      final isCommandRaw =
          rawType is String && kChatCommandTypes.contains(rawType);
      if (!asisten && !isCommandRaw && shouldShowActionFallback(
        action: parsed.action,
        reason: parsed.reason,
        reply: parsed.reply,
      )) {
        pending = buildPendingChatAction(
          reason: parsed.reason!,
          raw: parsed.actionRaw,
          walletNames: walletNames,
          categories: appCategories.value,
        );
      }
      // Map aksi tervalidasi -> TxDraft untuk kartu konfirmasi.
      // Uang tetap int dari parser; TxDraft pakai double (konversi aman).
      TxDraft? tx;
      final aMap = parsed.action;
      if (aMap != null && !asisten) {
        tx = TxDraft(
          type: aMap['type'] as String,
          amount: (aMap['amount'] as int).toDouble(),
          category: aMap['category'] as String?,
          note: aMap['note'] as String?,
          wallet: aMap['wallet'] as String?,
        );
      }
      final bill =
          asisten ? null : parseBillDraft(parseNamedBlock(r.text, 'tagihan'));
      final budget = asisten
          ? null
          : parseBudgetDraft(parseNamedBlock(r.text, 'budget'));
      setState(() {
        _items.add(_ChatMsg(
          mine: false,
          text: parsed.reply, // HANYA reply; JSON mentah tak pernah tampil
          provider: r.provider,
          action: tx,
          billAction: bill,
          budgetAction: budget,
          pendingAction: pending,
          command: asisten
              ? (parsed.command?['type'] == 'navigate'
                  ? parsed.command
                  : null)
              : parsed.command,
          viz: asisten ? parsed.viz : null,
          vizData: asisten ? snap : null,
          mode: _mode,
        ));
        _sending = false;
      });
    } on AiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _items.add(_ChatMsg(mine: false, text: _friendly(e), isError: true, mode: _mode));
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items.add(
            _ChatMsg(mine: false, text: tr('ai_fail'), isError: true, mode: _mode));
        _sending = false;
      });
    }
    unawaited(_saveSession());
    _toBottom();
  }

  Future<void> _openMemory() async {
    final facts = await loadAiMemory();
    final summaries = await loadAiSummaries();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SsrSpace.md),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('chat_mem_t'),
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: SsrSpace.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune_outlined),
                  title: Text(tr('ai_set_title')),
                  subtitle: Text(tr('ai_set_sub')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openPersonaSettings();
                  },
                ),
                const SizedBox(height: SsrSpace.sm),
                Text(tr('chat_mem_facts_t'),
                    style: Theme.of(ctx).textTheme.titleSmall),
                if (facts.isEmpty)
                  Text(tr('chat_mem_empty'),
                      style: Theme.of(ctx).textTheme.bodyMedium),
                for (final f in facts)
                  _memoryTile(
                    ctx,
                    text: f,
                    onEdit: () => _editMemoryItem(
                      ctx,
                      initial: f,
                      onSave: (v) => updateAiMemory(f, v),
                    ),
                    onDelete: () => removeAiMemory(f),
                  ),
                const SizedBox(height: SsrSpace.sm),
                Text(tr('chat_mem_sum_t'),
                    style: Theme.of(ctx).textTheme.titleSmall),
                if (summaries.isEmpty)
                  Text(tr('chat_mem_empty'),
                      style: Theme.of(ctx).textTheme.bodyMedium),
                for (final s in summaries)
                  _memoryTile(
                    ctx,
                    text: s,
                    onEdit: () => _editMemoryItem(
                      ctx,
                      initial: s,
                      onSave: (v) => updateAiSummary(s, v),
                    ),
                    onDelete: () => removeAiSummary(s),
                  ),
                const SizedBox(height: SsrSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await clearAiMemory();
                          await clearAiSummaries();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(tr('chat_mem_clear')),
                      ),
                    ),
                    const SizedBox(width: SsrSpace.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(tr('rcp_raw_close')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pengaturan personalisasi Mang AI (281C tahap 3): persona, nama
  /// panggilan, instruksi kustom. Tersimpan di prefs (ai_persona.dart)
  /// dan berlaku untuk kedua mode mulai pesan berikutnya.
  Future<void> _openPersonaSettings() async {
    var prefs = await loadAiPersona();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SsrSpace.md),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('ai_set_title'),
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: SsrSpace.sm),
                  Text(tr('ai_set_persona'),
                      style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: SsrSpace.xs),
                  Wrap(
                    spacing: SsrSpace.xs,
                    children: [
                      for (final e in kAiPersonaStyles.entries)
                        ChoiceChip(
                          label: Text(tr('ai_persona_${e.key}')),
                          selected: prefs.persona == e.key,
                          onSelected: (_) async {
                            prefs = prefs.copyWith(persona: e.key);
                            await saveAiPersona(prefs);
                            setSheet(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: SsrSpace.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('ai_set_nickname')),
                    subtitle: Text(prefs.nickname.isEmpty
                        ? tr('ai_set_empty')
                        : prefs.nickname),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      await _editMemoryItem(
                        ctx,
                        initial: prefs.nickname,
                        titleKey: 'ai_set_nickname',
                        onSave: (v) async {
                          prefs = prefs.copyWith(nickname: v.trim());
                          await saveAiPersona(prefs);
                        },
                      );
                      setSheet(() {});
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('ai_set_custom')),
                    subtitle: Text(prefs.customInstruction.isEmpty
                        ? tr('ai_set_empty')
                        : prefs.customInstruction),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      await _editMemoryItem(
                        ctx,
                        initial: prefs.customInstruction,
                        titleKey: 'ai_set_custom',
                        onSave: (v) async {
                          prefs =
                              prefs.copyWith(customInstruction: v.trim());
                          await saveAiPersona(prefs);
                        },
                      );
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(height: SsrSpace.sm),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr('rcp_raw_close')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Satu baris ingatan: teks + tombol ubah + hapus.
  Widget _memoryTile(
    BuildContext ctx, {
    required String text,
    required Future<void> Function() onEdit,
    required Future<void> Function() onDelete,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(text, style: Theme.of(ctx).textTheme.bodyMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: tr('chat_mem_edit'),
            onPressed: () async {
              await onEdit();
              if (ctx.mounted) Navigator.pop(ctx);
              _openMemory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await onDelete();
              if (ctx.mounted) Navigator.pop(ctx);
              _openMemory();
            },
          ),
        ],
      ),
    );
  }

  /// Dialog ubah teks satu ingatan (fakta / ringkasan).
  Future<void> _editMemoryItem(
    BuildContext ctx, {
    required String initial,
    required Future<void> Function(String) onSave,
    String titleKey = 'chat_mem_edit',
  }) async {
    final c = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(tr(titleKey)),
        content: TextField(
          controller: c,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(tr('ai_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(tr('chat_mem_save')),
          ),
        ],
      ),
    );
    final newText = c.text;
    c.dispose();
    if (ok == true) {
      await onSave(newText);
    }
  }

  /// Pilih provider AI: Mang AI Server (default — gratis, kuota per
  /// plan, tanpa setup) atau OpenCode Zen (API key sendiri, diatur di
  /// Pengaturan AI). Jalur OpenCode lokal sudah dihapus di 2.82.13+280.
  Future<void> _openProvider() async {
    var pick = _providerId == 'zen' ? 'zen' : 'server';
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: SsrSpace.md,
              right: SsrSpace.md,
              top: SsrSpace.md,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + SsrSpace.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('ai_prov_t'),
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: SsrSpace.sm),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'server', label: Text(tr('ai_prov_server'))),
                    ButtonSegment(
                        value: 'zen', label: Text(tr('ai_prov_zen'))),
                  ],
                  selected: {pick},
                  onSelectionChanged: (s) =>
                      setSheet(() => pick = s.first),
                ),
                const SizedBox(height: SsrSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await setAiProviderId(pick);
                          if (mounted) {
                            setState(() => _providerId = pick);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(tr('ai_prov_save')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Nama-nama dompet workspace aktif, untuk validasi aksi AI.
  /// Kosong = validasi longgar (string non-empty diterima).
  Future<List<String>> _walletNames() async {
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) return const [];
      final ws = await WalletService().list(orgId);
      return [for (final w in ws) w.name];
    } catch (_) {
      return const [];
    }
  }

  /// Ringkasan kartu konfirmasi dari DATA aksi tervalidasi (bukan teks model):
  /// jenis, nominal, kategori.
  String _actionTitle(TxDraft d) {
    final typeLabel = d.type == 'in'
        ? tr('tx_in')
        : d.type == 'transfer'
            ? tr('tx_transfer')
            : tr('tx_out');
    final cat = d.category == null ? '' : ' \u00b7 ${d.category}';
    return '$typeLabel \u00b7 ${d.amount.toStringAsFixed(0)}$cat';
  }

  /// Dompet + catatan untuk kartu konfirmasi.
  String? _actionNote(TxDraft d) {
    final parts = <String>[];
    if (d.wallet != null && d.wallet!.isNotEmpty) parts.add(d.wallet!);
    if (d.note != null && d.note!.isNotEmpty) parts.add(d.note!);
    return parts.isEmpty ? null : parts.join(' \u00b7 ');
  }

  /// Batalkan kartu aksi: hapus kartunya, pertahankan bubble teks.
  void _cancelActionCard(_ChatMsg m) {
    final idx = _items.indexOf(m);
    if (idx < 0 || !mounted) return;
    setState(() {
      _items[idx] = _ChatMsg(
        mine: false,
        text: m.text,
        provider: m.provider,
        mode: m.mode,
      );
    });
  }

  Future<void> _runAction(TxDraft d, {Map<String, dynamic>? aiValues}) async {
    String? walletId;
    if (d.wallet != null) {
      try {
        final orgId = await activeOrgId();
        if (orgId.isNotEmpty) {
          final ws = await WalletService().list(orgId);
          final hit = matchWalletName(
            d.wallet!,
            [for (final w in ws) w.name],
          );
          if (hit != null) {
            for (final w in ws) {
              if (w.name == hit) walletId = w.id;
            }
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final ok = await openTxInputSheet(
      context,
      initialType: d.type,
      initialAmountIdr: d.amount,
      initialCategory: d.category,
      initialWalletId: walletId,
      initialNote: d.note,
    );
    if (!mounted || !ok) return;
    // Tangkap referensi transaksi hasil form untuk edit_last /
    // delete_last: baris terbaru HARI INI yang cocok persis (tipe,
    // nominal, kategori, catatan) dan bukan hasil auto-track. User
    // bisa mengubah isi form -> tak cocok = tak ada referensi (aman).
    try {
      final orgId2 = await activeOrgId();
      if (orgId2.isNotEmpty) {
        final rows = await TransactionService().list(orgId2);
        final today = txWhen(DateTime.now()).date;
        for (final t in rows) {
          if (t.sourcePackage != null) continue;
          if (t.date != today) continue;
          if (t.type != d.type || t.amount != d.amount) continue;
          if ((t.category ?? '') != (d.category ?? '')) continue;
          if ((t.note ?? '') != (d.note ?? '')) continue;
          _lastChatTx = t;
          break;
        }
      }
    } catch (_) {}
    // Batch 281D tahap 1: event koreksi — bandingkan nilai AI vs
    // nilai final yang tersimpan dari form ini. Fail-open total:
    // kegagalan di sini tak pernah menghalangi bubble sukses.
    try {
      final orgId3 = await activeOrgId();
      if (orgId3.isNotEmpty) {
        final rows3 = await TransactionService().list(orgId3);
        final today3 = txWhen(DateTime.now()).date;
        SaasTransaction? finalTx;
        for (final t in rows3) {
          if (t.sourcePackage != null) continue;
          if (t.date != today3) continue;
          if (t.type != d.type || t.amount != d.amount) continue;
          if ((t.category ?? '') != (d.category ?? '')) continue;
          if ((t.note ?? '') != (d.note ?? '')) continue;
          finalTx = t;
          break;
        }
        if (finalTx == null) {
          final nowTs = DateTime.now();
          for (final t in rows3) {
            if (t.sourcePackage != null) continue;
            if (t.date != today3) continue;
            final ct = t.createdAt == null
                ? null
                : DateTime.tryParse(t.createdAt!);
            if (ct == null) continue;
            if (nowTs.difference(ct).inSeconds.abs() > 300) continue;
            if (finalTx == null ||
                (finalTx.createdAt ?? '').compareTo(t.createdAt ?? '') < 0) {
              finalTx = t;
            }
          }
        }
        final ft = finalTx;
        if (ft != null) {
          String? finalWallet;
          try {
            final ws3 = await WalletService().list(orgId3);
            for (final w in ws3) {
              if (w.id == ft.walletId) finalWallet = w.name;
            }
          } catch (_) {}
          final ev = buildCorrectionEvent(
            ai: aiValues ??
                <String, dynamic>{
                  'type': d.type,
                  'amount': d.amount,
                  'wallet': d.wallet,
                  'category': d.category,
                  'note': d.note,
                },
            fin: <String, dynamic>{
              'type': ft.type,
              'amount': ft.amount,
              'wallet': finalWallet,
              'category': ft.category,
              'note': ft.note,
            },
            sourceText: _lastUserText,
          );
          if (ev != null) {
            await recordCorrectionEvent(ev);
            unawaited(syncCorrectionEvents());
          }
          // Batch 281D tahap 2: alias merchant belajar dari
          // nilai final user (termasuk hasil koreksi di form).
          try {
            await upsertMerchantAlias(
              sourceText: ft.note ?? _lastUserText,
              category: ft.category,
              wallet: finalWallet,
            );
            unawaited(syncMerchantAliases());
          } catch (_) {}
        }
      }
    } catch (_) {}
    final sign = d.type == 'in' ? '+' : '-';
    setState(() {
      _items.add(_ChatMsg(
        mine: false,
        text: 'Tercatat ✓ $sign${d.amount.toStringAsFixed(0)}'
            '${d.category == null ? '' : ' · ${d.category}'}',
        provider: 'Mang AI',
      ));
    });
    _toBottom();
  }

  /// Simpan langsung satu ketuk dari kartu konfirmasi (inisiatif user,
  /// bukan otomatis). Tanggal = hari ini; dompet dicocokkan dari nama.
  Future<void> _saveAction(TxDraft d) async {
    String? walletId;
    String orgId = '';
    try {
      orgId = await activeOrgId();
      if (orgId.isNotEmpty && d.wallet != null) {
        final ws = await WalletService().list(orgId);
        final hit = matchWalletName(
          d.wallet!,
          [for (final w in ws) w.name],
        );
        if (hit != null) {
          for (final w in ws) {
            if (w.name == hit) walletId = w.id;
          }
        }
      }
    } catch (_) {}
    if (!mounted) return;
    if (orgId.isEmpty) {
      setState(() {
        _items.add(_ChatMsg(
          mine: false,
          text: tr('ai_save_no_org'),
          isError: true,
          provider: 'Mang AI',
        ));
      });
      _toBottom();
      return;
    }
    try {
      final when = txWhen(DateTime.now());
      final newId = await TransactionService().add(
        orgId: orgId,
        type: d.type,
        amount: d.amount,
        walletId: walletId,
        category: d.category,
        note: d.note,
        date: when.date,
        createdAt: when.createdAt,
      );
      // Referensi untuk edit_last/delete_last (batch 281): snapshot
      // lokal langsung; segarkan best-effort dari daftar (kode TX dll).
      _lastChatTx = SaasTransaction(
        id: newId,
        orgId: orgId,
        type: d.type,
        amount: d.amount,
        walletId: walletId,
        category: d.category,
        note: d.note,
        date: when.date,
        createdAt: when.createdAt,
      );
      try {
        final rows = await TransactionService().list(orgId);
        for (final t in rows) {
          if (t.id == newId) {
            _lastChatTx = t;
            break;
          }
        }
      } catch (_) {}
      // Batch 281D tahap 2: alias merchant belajar dari
      // pencatatan terkonfirmasi (simpan langsung). Fail-open.
      try {
        await upsertMerchantAlias(
          sourceText: d.note ?? _lastUserText,
          category: d.category,
          wallet: d.wallet,
        );
        unawaited(syncMerchantAliases());
      } catch (_) {}
    } catch (e) {
      // Gagal simpan aksi AI: user diberi tahu via bubble error (bukan silent).
      debugPrint('[ai_chat] simpan aksi gagal: $e');
      if (!mounted) return;
      setState(() {
        _items.add(_ChatMsg(
          mine: false,
          text: tr('ai_save_fail'),
          isError: true,
          provider: 'Mang AI',
        ));
      });
      _toBottom();
      return;
    }
    if (!mounted) return;
    final sign = d.type == 'in' ? '+' : '-';
    final amt = d.amount.toStringAsFixed(0);
    final cat = d.category == null ? '' : ' \u00b7 ${d.category!}';
    setState(() {
      _items.add(_ChatMsg(
        mine: false,
        text: 'Tersimpan \u2713 $sign$amt$cat',
        provider: 'Mang AI',
      ));
    });
    _toBottom();
  }

  /// Judul kartu perintah non-transaksi (batch 281).
  String _commandTitle(Map<String, dynamic> cmd) {
    switch (cmd['type']) {
      case 'navigate':
        return '${tr('ai_open')}: ${_navLabel(cmd['target'] as String? ?? '')}';
      case 'add_wallet':
        return '${tr('ai_cmd_add_wallet')}: ${cmd['name'] as String? ?? ''}';
      case 'add_category':
        return '${tr('ai_cmd_add_category')}: ${cmd['name'] as String? ?? ''}';
      case 'edit_last':
        return tr('ai_cmd_edit_last');
      case 'delete_last':
        return tr('ai_cmd_delete_last');
      default:
        return tr('ai_run');
    }
  }

  /// Keterangan kartu perintah (null = tanpa keterangan).
  String? _commandNote(Map<String, dynamic> cmd) {
    switch (cmd['type']) {
      case 'add_wallet':
        final parts = <String>[
          _walletTypeLabel(cmd['wallet_type'] as String? ?? 'cash'),
        ];
        final opening = cmd['opening_balance'] as int? ?? 0;
        if (opening > 0) {
          parts.add('${tr('ai_opening_balance')} $opening');
        }
        return parts.join(' \u00b7 ');
      case 'add_category':
        final kind = cmd['kind'] as String?;
        if (kind == 'in') return tr('tx_in');
        if (kind == 'out') return tr('tx_out');
        return null;
      case 'edit_last':
        final last = _lastChatTx;
        if (last == null) return tr('ai_cmd_no_last');
        final parts = <String>[_lastTxLabel(last)];
        final changes = <String>[];
        if (cmd['amount'] is int) changes.add('${cmd['amount']}');
        if (cmd['category'] is String) {
          changes.add(cmd['category'] as String);
        }
        if (cmd['wallet'] is String) changes.add(cmd['wallet'] as String);
        if (cmd['note'] is String) changes.add(cmd['note'] as String);
        if (changes.isNotEmpty) parts.add(changes.join(' \u00b7 '));
        return parts.join(' \u2192 ');
      case 'delete_last':
        final last = _lastChatTx;
        if (last == null) return tr('ai_cmd_no_last');
        return _lastTxLabel(last);
      default:
        return null;
    }
  }

  /// Ringkasan satu baris transaksi terakhir dari chat.
  String _lastTxLabel(SaasTransaction t) {
    final sign = t.type == 'in' ? '+' : '-';
    final cat = t.category == null ? '' : ' \u00b7 ${t.category}';
    return '$sign${t.amount.toStringAsFixed(0)}$cat';
  }

  String _walletTypeLabel(String t) {
    switch (t) {
      case 'ewallet':
        return tr('w_ewallet');
      case 'bank':
        return tr('w_bank');
      case 'investment':
        return tr('w_investment');
      default:
        return tr('w_cash');
    }
  }

  /// Label tombol utama kartu perintah (null = label bawaan).
  String? _commandRunLabel(Map<String, dynamic> cmd) {
    if (cmd['type'] == 'navigate') return tr('ai_open');
    if (cmd['type'] == 'delete_last') return tr('ai_del_ok');
    return null;
  }

  String _navLabel(String target) {
    switch (target) {
      case 'nfc':
        return tr('ai_nav_nfc');
      case 'laporan':
        return tr('ai_nav_laporan');
      case 'billing':
        return tr('ai_nav_billing');
      case 'dompet':
        return tr('ai_nav_dompet');
      case 'kategori':
        return tr('ai_nav_kategori');
      case 'anggaran':
        return tr('ai_nav_anggaran');
      case 'tagihan':
        return tr('ai_nav_tagihan');
      case 'profil':
        return tr('ai_nav_profil');
      default:
        return target;
    }
  }

  /// Layar untuk target navigasi; null = target tak dikenal (abaikan aman).
  Widget? _navScreen(String target) {
    switch (target) {
      case 'nfc':
        return const NfcCardsScreen();
      case 'laporan':
        return const ReportsScreen();
      case 'billing':
        return const BillingScreen();
      case 'dompet':
        return const WalletsScreen();
      case 'kategori':
        return const CategoriesScreen();
      case 'anggaran':
        return const BudgetsScreen();
      case 'tagihan':
        return const RecurringBillsScreen();
      case 'profil':
        return const SettingsScreen();
    }
    return null;
  }

  /// Eksekutor perintah non-transaksi; jalan HANYA dari kartu konfirmasi.
  Future<void> _runCommand(Map<String, dynamic> cmd) async {
    switch (cmd['type']) {
      case 'navigate':
        final screen = _navScreen(cmd['target'] as String? ?? '');
        if (screen == null || !mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
        break;
      case 'add_wallet':
        await _runAddWallet(cmd);
        break;
      case 'add_category':
        await _runAddCategory(cmd);
        break;
      case 'edit_last':
        await _runEditLast(cmd);
        break;
      case 'delete_last':
        await _runDeleteLast();
        break;
    }
  }

  /// Ubah transaksi terakhir dari chat: buka form edit (mode editing)
  /// dengan usulan perubahan model diterapkan ke salinan transaksi;
  /// user meninjau + menyimpan sendiri di form (update by id di sheet).
  Future<void> _runEditLast(Map<String, dynamic> cmd) async {
    final last = _lastChatTx;
    if (last == null) {
      _commandBubble(tr('ai_cmd_no_last'), isError: true);
      return;
    }
    var walletId = last.walletId;
    final walletName = cmd['wallet'] as String?;
    if (walletName != null) {
      try {
        final ws = await WalletService().list(last.orgId);
        final hit = matchWalletName(
          walletName,
          [for (final w in ws) w.name],
        );
        if (hit != null) {
          for (final w in ws) {
            if (w.name == hit) walletId = w.id;
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final edited = SaasTransaction(
      id: last.id,
      orgId: last.orgId,
      type: last.type,
      amount: (cmd['amount'] as int?)?.toDouble() ?? last.amount,
      walletId: walletId,
      toWalletId: last.toWalletId,
      category: (cmd['category'] as String?) ?? last.category,
      note: cmd.containsKey('note') ? (cmd['note'] as String?) : last.note,
      date: last.date,
      code: last.code,
      createdAt: last.createdAt,
      sourcePackage: last.sourcePackage,
      sourceHash: last.sourceHash,
      createdBy: last.createdBy,
    );
    final ok = await openTxInputSheet(context, editing: edited);
    if (!mounted || !ok) return;
    try {
      final rows = await TransactionService().list(last.orgId);
      var refreshed = false;
      for (final t in rows) {
        if (t.id == last.id) {
          _lastChatTx = t;
          refreshed = true;
          break;
        }
      }
      if (!refreshed) _lastChatTx = edited;
    } catch (_) {
      _lastChatTx = edited;
    }
    _commandBubble('Transaksi terakhir diubah \u2713');
  }

  /// Hapus transaksi terakhir dari chat: WAJIB dialog konfirmasi
  /// eksplisit terpisah sebelum delete() dipanggil (bukan sekali tap).
  Future<void> _runDeleteLast() async {
    final last = _lastChatTx;
    if (last == null) {
      _commandBubble(tr('ai_cmd_no_last'), isError: true);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('ai_del_last_t')),
        content: Text(
          '${tr('ai_del_last_m')}\n\n${_lastTxLabel(last)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('ai_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('ai_del_ok')),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    try {
      await TransactionService().delete(last.id, last.orgId);
    } catch (e) {
      debugPrint('[ai_chat] hapus transaksi terakhir gagal: $e');
      _commandBubble(tr('ai_save_fail'), isError: true);
      return;
    }
    _lastChatTx = null;
    _commandBubble('Transaksi terakhir dihapus \u2713');
  }

  /// Bubble hasil perintah (sukses/gagal) sebagai pesan Mang AI.
  void _commandBubble(String text, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _items.add(_ChatMsg(
        mine: false,
        text: text,
        isError: isError,
        provider: 'Mang AI',
        mode: _mode,
      ));
    });
    _toBottom();
    unawaited(_saveSession());
  }

  /// Buat dompet baru: jalur yang sama seperti form manual
  /// (WalletService.create + transaksi 'Saldo awal' bila ada saldo
  /// awal; gagal saldo awal -> dompet dibatalkan, pola wallets_screen).
  Future<void> _runAddWallet(Map<String, dynamic> cmd) async {
    final name = (cmd['name'] as String? ?? '').trim();
    if (name.isEmpty) return;
    final type = cmd['wallet_type'] as String? ?? 'cash';
    final opening = cmd['opening_balance'] as int? ?? 0;
    String orgId = '';
    try {
      orgId = await activeOrgId();
    } catch (_) {}
    if (!mounted) return;
    if (orgId.isEmpty) {
      _commandBubble(tr('ai_save_no_org'), isError: true);
      return;
    }
    try {
      final ws = await WalletService().list(orgId);
      if (ws.any((w) => w.name.toLowerCase() == name.toLowerCase())) {
        _commandBubble(tr('ai_wallet_exists'), isError: true);
        return;
      }
      final id = await WalletService().create(orgId, name, type);
      if (opening > 0) {
        try {
          final when = txWhen(DateTime.now());
          await TransactionService().add(
            orgId: orgId,
            type: 'in',
            amount: opening.toDouble(),
            walletId: id,
            category: 'Saldo awal',
            note: 'Saldo awal $name',
            date: when.date,
            createdAt: when.createdAt,
          );
        } catch (_) {
          try {
            await WalletService().deleteWallet(id, orgId);
          } catch (_) {}
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('[ai_chat] tambah dompet gagal: $e');
      _commandBubble(tr('ai_save_fail'), isError: true);
      return;
    }
    _commandBubble('Dompet ditambah \u2713 $name');
  }

  /// Buat kategori baru lewat jalur yang sama seperti layar kategori
  /// (saveAppCategories atas daftar appCategories aktif).
  Future<void> _runAddCategory(Map<String, dynamic> cmd) async {
    final name = (cmd['name'] as String? ?? '').trim();
    if (name.isEmpty) return;
    final exists =
        appCategories.value.any((c) => c.toLowerCase() == name.toLowerCase());
    if (exists) {
      _commandBubble(tr('ai_cat_exists'), isError: true);
      return;
    }
    await saveAppCategories([...appCategories.value, name]);
    _commandBubble('Kategori ditambah \u2713 $name');
  }

  Future<void> _runBill(BillDraft d) async {
    try {
      final bills = await loadBills();
      final now = DateTime.now();
      final anchor = now.day > 28 ? 28 : now.day;
      final nm = now.month == 12
          ? DateTime(now.year + 1, 1, anchor)
          : DateTime(now.year, now.month + 1, anchor);
      final due =
          '${nm.year}-${nm.month.toString().padLeft(2, '0')}-${nm.day.toString().padLeft(2, '0')}';
      bills.add(RecurringBill(
        id: const Uuid().v4(),
        label: d.label,
        amount: d.amount,
        category: d.category ?? '',
        walletId: '',
        period: 'monthly',
        anchorDay: anchor,
        nextDue: due,
        active: true,
      ));
      await saveBills(bills);
      if (!mounted) return;
      setState(() {
        _items.add(_ChatMsg(
          mine: false,
          text: 'Tagihan "${d.label}" tercatat ✓ '
              '(${d.amount.toStringAsFixed(0)}, jatuh $due)',
          provider: 'Mang AI',
        ));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items.add(_ChatMsg(
            mine: false, text: tr('ai_fail'), isError: true));
      });
    }
    _toBottom();
  }

  Future<void> _runBudget(BudgetDraft d) async {
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) throw StateError('tanpa workspace');
      await setBudget(orgId, d.category, d.limit);
      if (!mounted) return;
      setState(() {
        _items.add(_ChatMsg(
          mine: false,
          text: 'Budget ${d.category} = ${d.limit.toStringAsFixed(0)} ✓',
          provider: 'Mang AI',
        ));
      });
    } on QuotaExceededException catch (e) {
      if (!mounted) return;
      await requirePro(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items.add(_ChatMsg(
            mine: false, text: tr('ai_fail'), isError: true));
      });
    }
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visibleItems;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('chat_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'Pengaturan AI',
            onPressed: () async {
              try {
                await const MethodChannel('ssr_space/ai').invokeMethod('openSettings');
              } catch (_) {}
            },
          ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: tr('chat_mem_t'),
            onPressed: _openMemory,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_outlined),
            tooltip: tr('chat_menu'),
            onSelected: (v) async {
              if (v != 'new' || _sending) return;
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(tr('chat_new_t')),
                  content: Text(tr('chat_new_m')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(tr('ai_cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(tr('chat_new_ok')),
                    ),
                  ],
                ),
              );
              if (ok == true && mounted) {
                setState(() {
                  _items.clear();
                  _lastChatTx = null;
                });
                unawaited(_clearSession());
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'new',
                child: Text(tr('chat_new')),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SsrSpace.md, SsrSpace.sm, SsrSpace.md, 0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(
                      value: 'catat',
                      label: Text(tr('ai_mode_catat')),
                      icon: const Icon(Icons.edit_note_outlined),
                    ),
                    ButtonSegment<String>(
                      value: 'asisten',
                      label: Text(tr('ai_mode_asisten')),
                      icon: const Icon(Icons.insights_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => _setMode(s.first),
                ),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(SsrSpace.lg),
                        child: Text(
                          tr('chat_empty'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(SsrSpace.md),
                      itemCount: visible.length + (_sending ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= visible.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: _TypingDots(),
                            ),
                          );
                        }
                        final m = visible[i];
                        return _Enter(
                          animate: i >= _animFrom,
                          mine: m.mine,
                          child: Column(
                            crossAxisAlignment: m.mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            _Bubble(msg: m),
                            if (m.viz != null && m.vizData != null)
                              _VizCard(viz: m.viz!, data: m.vizData!),
                            if (m.action != null)
                              _ActionCard(
                                title: _actionTitle(m.action!),
                                note: _actionNote(m.action!),
                                onRun: () => _runAction(m.action!),
                                onSave: () => _saveAction(m.action!),
                                onCancel: () => _cancelActionCard(m),
                              ),
                            if (m.pendingAction != null)
                              _PendingActionCard(
                                pending: m.pendingAction!,
                                onRun: (d) => _runAction(d, aiValues: {
                                  'type': m.pendingAction!.type,
                                  'amount':
                                      m.pendingAction!.amount.toDouble(),
                                  'wallet': m.pendingAction!.walletOk ??
                                      m.pendingAction!.walletBad,
                                  'category': m.pendingAction!.categoryOk ??
                                      m.pendingAction!.categoryBad,
                                  'note': m.pendingAction!.note,
                                }),
                                onCancel: () => _cancelActionCard(m),
                              ),
                            if (m.billAction != null)
                              _ActionCard(
                                title:
                                    '${m.billAction!.label} · ${m.billAction!.amount.toStringAsFixed(0)}',
                                note: tr('mode_bill_s'),
                                onRun: () => _runBill(m.billAction!),
                                onCancel: () => _cancelActionCard(m),
                              ),
                            if (m.budgetAction != null)
                              _ActionCard(
                                title:
                                    '${m.budgetAction!.category} · ${m.budgetAction!.limit.toStringAsFixed(0)}',
                                note: tr('mode_budget_s'),
                                onRun: () => _runBudget(m.budgetAction!),
                                onCancel: () => _cancelActionCard(m),
                              ),
                            if (m.command != null)
                              _ActionCard(
                                title: _commandTitle(m.command!),
                                note: _commandNote(m.command!),
                                runLabel: _commandRunLabel(m.command!),
                                onRun: () => _runCommand(m.command!),
                                onCancel: () => _cancelActionCard(m),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (_pendingImage != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: SsrSpace.md,
                    bottom: SsrSpace.xs,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          Uint8List.fromList(_pendingImage!),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: () => setState(() {
                            _pendingImage = null;
                            _pendingMime = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.close,
                                size: 16,
                                color: scheme.onErrorContainer),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SsrSpace.md,
                SsrSpace.sm,
                SsrSpace.md,
                SsrSpace.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ActionChip(
                    label: Text(_providerId == 'zen'
                        ? tr('ai_prov_zen')
                        : tr('ai_prov_server')),
                    avatar: const Icon(Icons.smart_toy_outlined, size: 16),
                    onPressed: _sending ? null : _openProvider,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined),
                    tooltip: tr('chat_attach'),
                    onPressed: _sending ? null : _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _c,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: tr('chat_hint'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: SsrSpace.sm),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(),
                    icon: const Icon(Icons.send),
                  ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrance halus bubble baru (fade + geser 12px, 250ms).
/// Bubble lama (animate=false) tampil instan tanpa replay.
class _Enter extends StatelessWidget {
  final bool animate;
  final bool mine;
  final Widget child;
  const _Enter({
    required this.animate,
    required this.mine,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset((mine ? 1 : -1) * (1 - v) * 12, (1 - v) * 8),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

/// Tiga titik mengetik berdenyut berurutan (loop).
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
              child: Opacity(
                opacity:
                    (0.35 + 0.65 * ((_c.value + i / 3) % 1.0)).clamp(0.0, 1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {  final _ChatMsg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Bubble iOS: user biru-putih, Mang AI abu netral, error merah.
    // Satu-satunya aksen biru di layar (R-01, R-29).
    final bg = msg.mine
        ? scheme.primary
        : msg.isError
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest;
    final fg = msg.mine
        ? scheme.onPrimary
        : msg.isError
            ? scheme.onErrorContainer
            : scheme.onSurface;
    return Align(
      alignment: msg.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: SsrSpace.md,
          vertical: SsrSpace.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  Uint8List.fromList(msg.image!),
                  width: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 6),
            ],
            // Rebrand: nama model disembunyikan, semua = Mang AI.
            if (msg.provider != null && !msg.mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  tr('chat_mang'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: fg.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            SelectableText(
              msg.text,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu konfirmasi aksi dari AI (transaksi/tagihan/budget): user ketuk
/// Jalankan -> eksekusi nyata. Tanpa auto-eksekusi.
class _ActionCard extends StatelessWidget {
  final String title;
  final String? note;
  final VoidCallback onRun;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;

  /// Label tombol utama; null = tr('ai_run') bawaan.
  final String? runLabel;
  const _ActionCard({
    required this.title,
    this.note,
    required this.onRun,
    this.onSave,
    this.onCancel,
    this.runLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2, bottom: 4),
        padding: const EdgeInsets.all(SsrSpace.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(
                note!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
              ),
            ],
            const SizedBox(height: SsrSpace.sm),
            Row(
              children: [
                if (onCancel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      child: Text(tr('ai_cancel')),
                    ),
                  ),
                  const SizedBox(width: SsrSpace.sm),
                ],
                if (onSave != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(tr('ai_tx_save')),
                    ),
                  ),
                  const SizedBox(width: SsrSpace.sm),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: onRun,
                    child: Text(runLabel ?? tr('ai_run')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu fallback: aksi AI ditolak validasi padahal reply menjanjikan
/// konfirmasi. Tampilkan data yang sudah terisi + dropdown untuk field
/// bermasalah (dompet/kategori), atau pesan jelas apa yang kurang.
/// Tanpa simpan otomatis: data hanya dipakai saat user tekan Jalankan.
class _PendingActionCard extends StatefulWidget {
  final PendingChatAction pending;
  final void Function(TxDraft) onRun;
  final VoidCallback onCancel;
  const _PendingActionCard({
    required this.pending,
    required this.onRun,
    required this.onCancel,
  });

  @override
  State<_PendingActionCard> createState() => _PendingActionCardState();
}

class _PendingActionCardState extends State<_PendingActionCard> {
  String? _wallet;
  String? _category;

  @override
  void initState() {
    super.initState();
    _wallet = widget.pending.walletOk;
    _category = widget.pending.categoryOk;
  }

  /// Pesan jelas (Indonesia) tentang apa yang kurang dari AI.
  String _reasonMessage(PendingChatAction p) {
    switch (p.reason) {
      case 'wallet_tidak_cocok':
        return 'Dompet "${p.walletBad ?? ''}" tidak dikenal. Pilih dompet yang benar:';
      case 'wallet_kosong':
        return 'Dompetnya belum jelas. Pilih dompet:';
      case 'kategori_tidak_cocok':
        return 'Kategori "${p.categoryBad ?? ''}" tidak dikenal. Pilih kategori:';
      case 'kategori_kosong':
        return 'Kategorinya belum jelas. Pilih kategori:';
      case 'amount_invalid':
        return 'Nominal dari AI tidak valid. Coba sebutkan nominalnya, mis. "catat keluar 16000".';
      case 'type_invalid':
        return 'Jenis transaksi dari AI tidak valid.';
      case 'action_null':
        return 'AI tidak menyertakan data transaksi. Coba sebutkan nominal, kategori, dan dompetnya.';
      default:
        return 'Data dari AI tidak lengkap. Coba kirim lagi.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pending;
    final scheme = Theme.of(context).colorScheme;
    final needWallet = p.fixable && p.walletOk == null;
    final needCategory = p.fixable && p.categoryOk == null;
    final canRun = p.fixable && _wallet != null && _category != null;
    final typeLabel = p.type == 'in'
        ? tr('tx_in')
        : p.type == 'transfer'
            ? tr('tx_transfer')
            : tr('tx_out');
    final summary = p.fixable
        ? '$typeLabel \u00b7 ${p.amount}'
            '${_category != null ? ' \u00b7 $_category' : ''}'
            '${_wallet != null ? ' \u00b7 $_wallet' : ''}'
        : typeLabel;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2, bottom: 4),
        padding: const EdgeInsets.all(SsrSpace.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lengkapi data \u00b7 $summary',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _reasonMessage(p),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
            ),
            if (needWallet) ...[
              const SizedBox(height: SsrSpace.xs),
              if (p.walletOptions.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _wallet,
                  hint: const Text('Pilih dompet'),
                  items: [
                    for (final w in p.walletOptions)
                      DropdownMenuItem(value: w, child: Text(w)),
                  ],
                  onChanged: (v) => setState(() => _wallet = v),
                )
              else
                Text(
                  'Daftar dompet tidak tersedia.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            if (needCategory) ...[
              const SizedBox(height: SsrSpace.xs),
              if (p.categoryOptions.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  hint: const Text('Pilih kategori'),
                  items: [
                    for (final c in p.categoryOptions)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                )
              else
                Text(
                  'Daftar kategori tidak tersedia.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            const SizedBox(height: SsrSpace.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: canRun
                        ? () => widget.onRun(TxDraft(
                              type: p.type,
                              amount: p.amount.toDouble(),
                              category: _category,
                              wallet: _wallet,
                              note: p.note,
                            ))
                        : null,
                    child: Text(tr('ai_run')),
                  ),
                ),
                const SizedBox(width: SsrSpace.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    child: Text(tr('ai_cancel')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu visualisasi Mode Asisten (281C tahap 2): angka SELALU dari
/// snapshot lokal app; model hanya memilih jenis kartu. Viz tanpa
/// data pendukung dirender sebagai widget kosong (aman).
class _VizCard extends StatelessWidget {
  final Map<String, dynamic> viz;
  final AssistantSnapshot data;
  const _VizCard({required this.viz, required this.data});

  String _amt(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = viz['type'] as String? ?? '';
    var title = '';
    final rows = <Widget>[];
    if (type == 'saldo') {
      title = tr('ai_viz_saldo');
      for (final w in data.wallets) {
        rows.add(_VizRow(label: w.name, value: _amt(w.balance)));
      }
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 12));
        rows.add(_VizRow(
            label: tr('ai_viz_total'),
            value: _amt(data.totalBalance),
            bold: true));
      }
    } else if (type == 'rincian_kategori') {
      title = tr('ai_viz_kategori');
      final limit = (viz['limit'] as int?) ?? 5;
      final cats = data.topCategories.take(limit).toList();
      final max = cats.isEmpty ? 0.0 : cats.first.total;
      for (final c in cats) {
        rows.add(_VizRow(label: c.name, value: _amt(c.total)));
        rows.add(_VizBar(
            frac: max > 0 ? c.total / max : 0, color: scheme.primary));
      }
    } else if (type == 'tren_ringkas') {
      title = tr('ai_viz_tren');
      var max = 0.0;
      for (final d in data.last7) {
        if (d.outAmt > max) max = d.outAmt;
      }
      for (final d in data.last7) {
        final lbl = d.day.length >= 10 ? d.day.substring(5) : d.day;
        rows.add(_VizRow(
            label: lbl, value: '-${_amt(d.outAmt)} / +${_amt(d.inAmt)}'));
        rows.add(_VizBar(
            frac: max > 0 ? d.outAmt / max : 0, color: scheme.primary));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2, bottom: 4),
        padding: const EdgeInsets.all(SsrSpace.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: SsrSpace.sm),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _VizRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _VizRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _VizBar extends StatelessWidget {
  final double frac;
  final Color color;
  const _VizBar({required this.frac, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: frac.clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: color.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}

