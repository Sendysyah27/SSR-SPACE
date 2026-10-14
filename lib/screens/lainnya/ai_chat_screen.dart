import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:ssr_space/services/ai_context.dart';
import 'package:ssr_space/services/ai_memory.dart';
import 'package:ssr_space/services/ai_soul.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/quick_input_parse.dart';
import 'package:ssr_space/services/recurring_bills.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/services/ai_zen_client.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/tx_input_sheet.dart';

/// Room chat AI: tanya apa saja (+ lampiran gambar), jawab via provider
/// aktif (Gemini -> OpenRouter -> Zen -> Firebase). Riwayat sesi ini
/// saja (memori, tak disimpan). Fakta ```ingat``` tersimpan otomatis;
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
  const _ChatMsg({
    required this.mine,
    required this.text,
    this.provider,
    this.isError = false,
    this.image,
    this.action,
    this.billAction,
    this.budgetAction,
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
  int _animFrom = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskData());
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

  String _friendly(AiFailure e) {
    if (e.code == 'quota') return quotaWaitLine(e.detail);
    final d = e.detail ?? '';
    if (d.startsWith('[Gambar]')) return d;
    return tr(aiMessageKey(e.code));
  }

  Future<void> _pickImage() async {
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
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
    final memory = await loadAiMemory();
    if (!mounted) return;
    final prompt = text.isEmpty
        ? '${aiContextBlock(memory)}\nJelaskan gambar terlampir.'
        : '${aiContextBlock(memory)}\nUser: $text';
    setState(() {
      _animFrom = _items.length;
      _items.add(_ChatMsg(mine: true, text: text.isEmpty ? '(gambar)' : text,
          image: img));
      _c.clear();
      _pendingImage = null;
      _pendingMime = null;
      _sending = true;
    });
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
      if (!mounted) return;
      unawaited(
          addAiMemory(parseIngatBlocks(r.text)).then((_) async {
        final n = await loadAiMemory();
        debugPrint('ai memori: ${n.length} fakta');
      }));
      final tx = parseTxDraft(parseTxBlock(r.text));
      final bill = parseBillDraft(parseNamedBlock(r.text, 'tagihan'));
      final budget = parseBudgetDraft(parseNamedBlock(r.text, 'budget'));
      setState(() {
        _items.add(_ChatMsg(
          mine: false,
          text: r.text,
          provider: r.provider,
          action: tx,
          billAction: bill,
          budgetAction: budget,
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
    _toBottom();
  }

  Future<void> _openMemory() async {
    final facts = await loadAiMemory();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SsrSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('chat_mem_t'),
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: SsrSpace.sm),
              if (facts.isEmpty)
                Text(tr('chat_mem_empty'),
                    style: Theme.of(ctx).textTheme.bodyMedium),
              for (final f in facts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(f,
                      style: Theme.of(ctx).textTheme.bodyMedium),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await removeAiMemory(f);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _openMemory();
                    },
                  ),
                ),
              const SizedBox(height: SsrSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await clearAiMemory();
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
    );
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
            icon: const Icon(Icons.psychology_outlined),
            tooltip: tr('chat_mem_t'),
            onPressed: _openMemory,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_outlined),
            tooltip: tr('chat_reset'),
            onPressed: _sending
                ? null
                : () => setState(() {
                      _items.clear();
                    }),
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
                                title:
                                    '${m.action!.type == 'in' ? '+' : '-'}'
                                    '${m.action!.amount.toStringAsFixed(0)}'
                                    '${m.action!.category == null ? '' : ' · ${m.action!.category}'}',
                                note: m.action!.note,
                                onRun: () => _runAction(m.action!),
                              ),
                            if (m.billAction != null)
                              _ActionCard(
                                title:
                                    '${m.billAction!.label} · ${m.billAction!.amount.toStringAsFixed(0)}',
                                note: tr('mode_bill_s'),
                                onRun: () => _runBill(m.billAction!),
                              ),
                            if (m.budgetAction != null)
                              _ActionCard(
                                title:
                                    '${m.budgetAction!.category} · ${m.budgetAction!.limit.toStringAsFixed(0)}',
                                note: tr('mode_budget_s'),
                                onRun: () => _runBudget(m.budgetAction!),
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
              child: Row(
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
  const _ActionCard({
    required this.title,
    this.note,
    required this.onRun,
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onRun,
                child: Text(tr('ai_run')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
