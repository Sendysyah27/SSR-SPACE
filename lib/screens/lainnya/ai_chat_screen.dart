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
import 'package:ssr_space/services/ai_key_store.dart';
import 'package:ssr_space/services/ai_memory.dart';
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
import 'package:ssr_space/services/ai_zen_client.dart';
import 'package:ssr_space/services/ai_quota.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';
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
  String _dataCtx = '';
  String _providerId = 'zen';
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
    // Server OpenCode lokal mati / tak terjangkau.
    if (low.contains('server lokal') ||
        low.contains('opencode serve') ||
        low.contains('connection refused') ||
        low.contains('failed to connect') ||
        low.contains('127.0.0.1') ||
        low.contains('localhost')) {
      return tr('ai_err_local_down');
    }
    // Timeout (Dart) maupun timeout native.
    if (e.code == 'timeout' || low.contains('timeout')) {
      return tr('ai_err_timeout');
    }
    // Password OpenCode lokal belum diisi.
    if (low.contains('belum ada password')) {
      return tr('ai_err_local_pass');
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
    final prompt = text.isEmpty
        ? '${aiContextBlock(memory, summaries)}\nJelaskan gambar terlampir.'
        : '${aiContextBlock(memory, summaries)}\nUser: $text';
    setState(() {
      _animFrom = _items.length;
      _items.add(_ChatMsg(mine: true, text: text.isEmpty ? '(gambar)' : text,
          image: img));
      _c.clear();
      _pendingImage = null;
      _pendingMime = null;
      _sending = true;
    });
    unawaited(_saveSession());
    _toBottom();
    // Riwayat sesi sebagai konteks (maks 10 turn terakhir).
    final history = [
      for (final m in _items)
        (mine: m.mine, text: m.image != null ? '${m.text} [gambar]' : m.text),
    ];
    try {
      final r = await aiChat(prompt,
          imageBytes: img,
          mimeType: mime,
          history: history,
          dataContext: _dataCtx.isEmpty ? null : _dataCtx);
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
      if (shouldShowActionFallback(
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
      if (aMap != null) {
        tx = TxDraft(
          type: aMap['type'] as String,
          amount: (aMap['amount'] as int).toDouble(),
          category: aMap['category'] as String?,
          note: aMap['note'] as String?,
          wallet: aMap['wallet'] as String?,
        );
      }
      final bill = parseBillDraft(parseNamedBlock(r.text, 'tagihan'));
      final budget = parseBudgetDraft(parseNamedBlock(r.text, 'budget'));
      setState(() {
        _items.add(_ChatMsg(
          mine: false,
          text: parsed.reply, // HANYA reply; JSON mentah tak pernah tampil
          provider: r.provider,
          action: tx,
          billAction: bill,
          budgetAction: budget,
          pendingAction: pending,
        ));
        _sending = false;
      });
    } on AiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _items.add(_ChatMsg(mine: false, text: _friendly(e), isError: true));
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items.add(
            _ChatMsg(mine: false, text: tr('ai_fail'), isError: true));
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
  }) async {
    final c = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(tr('chat_mem_edit')),
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

  /// Pilih provider AI (Zen API / OpenCode lokal) + baseUrl + password.
  /// Password tersimpan di secure storage, tak pernah di-log/di-debug.
  Future<void> _openProvider() async {
    var pick = _providerId == 'local' ? 'local' : 'zen';
    final urlC = TextEditingController(text: await aiBaseUrl());
    final passC = TextEditingController();
    final hasPass = await readLocalPass() != null;
    if (!mounted) return;
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
                        value: 'zen', label: Text(tr('ai_prov_zen'))),
                    ButtonSegment(
                        value: 'local', label: Text(tr('ai_prov_local'))),
                  ],
                  selected: {pick},
                  onSelectionChanged: (s) =>
                      setSheet(() => pick = s.first),
                ),
                if (pick == 'local') ...[
                  const SizedBox(height: SsrSpace.sm),
                  TextField(
                    controller: urlC,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: tr('ai_prov_url'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: SsrSpace.sm),
                  TextField(
                    controller: passC,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText:
                          '${tr('ai_prov_pass')}${hasPass ? ' (***)' : ''}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(tr('ai_prov_hint'),
                      style: Theme.of(ctx).textTheme.bodySmall),
                ],
                const SizedBox(height: SsrSpace.sm),
                Row(
                  children: [
                    if (pick == 'local')
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await clearLocalPass();
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text(tr('ai_prov_clear')),
                        ),
                      ),
                    if (pick == 'local')
                      const SizedBox(width: SsrSpace.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await setAiProviderId(pick);
                          if (pick == 'local') {
                            await setAiBaseUrl(urlC.text);
                            // Kosong = biarkan password lama.
                            if (passC.text.trim().isNotEmpty) {
                              await writeLocalPass(passC.text);
                            }
                          }
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
    urlC.dispose();
    passC.dispose();
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
      );
    });
  }

  Future<void> _runAction(TxDraft d) async {
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
      await TransactionService().add(
        orgId: orgId,
        type: d.type,
        amount: d.amount,
        walletId: walletId,
        category: d.category,
        note: d.note,
        date: when.date,
        createdAt: when.createdAt,
      );
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
                setState(() => _items.clear());
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
            Expanded(
              child: _items.isEmpty
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
                      itemCount: _items.length + (_sending ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= _items.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: _TypingDots(),
                            ),
                          );
                        }
                        final m = _items[i];
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
                                onRun: (d) => _runAction(d),
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
                    label: Text(_providerId == 'local'
                        ? tr('ai_prov_local')
                        : tr('ai_prov_zen')),
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
  const _ActionCard({
    required this.title,
    this.note,
    required this.onRun,
    this.onSave,
    this.onCancel,
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
                    child: Text(tr('ai_run')),
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
