import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ssr_space/services/ai_memory.dart';
import 'package:ssr_space/services/ai_soul.dart';
import 'package:ssr_space/services/firebase_ai_factory.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';
import 'package:ssr_space/theme/app_theme.dart';
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
  const _ChatMsg({
    required this.mine,
    required this.text,
    this.provider,
    this.isError = false,
    this.image,
    this.action,
  });
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _items = <_ChatMsg>[];
  final _c = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  List<int>? _pendingImage;
  String? _pendingMime;

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
      _items.add(_ChatMsg(mine: true, text: text.isEmpty ? '(gambar)' : text,
          image: img));
      _c.clear();
      _pendingImage = null;
      _pendingMime = null;
      _sending = true;
    });
    _toBottom();
    try {
      final r = await aiChat(prompt, imageBytes: img, mimeType: mime);
      if (!mounted) return;
      unawaited(
          addAiMemory(parseIngatBlocks(r.text)).then((_) async {
        final n = await loadAiMemory();
        debugPrint('ai memori: ${n.length} fakta');
      }));
      final tx = parseTxDraft(parseTxBlock(r.text));
      setState(() {
        _items.add(_ChatMsg(
          mine: false,
          text: r.text,
          provider: r.provider,
          action: tx,
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
    await openTxInputSheet(
      context,
      initialType: d.type,
      initialAmountIdr: d.amount,
      initialCategory: d.category,
      initialNote: d.note,
    );
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
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                tr('chat_thinking'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          );
                        }
                        final m = _items[i];
                        return Column(
                          crossAxisAlignment: m.mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Bubble(msg: m),
                            if (m.action != null)
                              _ActionCard(
                                draft: m.action!,
                                onRun: () => _runAction(m.action!),
                              ),
                          ],
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

class _Bubble extends StatelessWidget {
  final _ChatMsg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = msg.mine
        ? scheme.primaryContainer
        : msg.isError
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest;
    final fg = msg.mine
        ? scheme.onPrimaryContainer
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
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  Uint8List.fromList(msg.image!),
                  width: 180,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (msg.provider != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  msg.provider!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: fg.withValues(alpha: 0.7),
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

/// Kartu konfirmasi aksi transaksi dari AI: user ketuk Jalankan ->
/// form prefill (user tetap yang simpan). Tanpa auto-eksekusi.
class _ActionCard extends StatelessWidget {
  final TxDraft draft;
  final VoidCallback onRun;
  const _ActionCard({required this.draft, required this.onRun});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sign = draft.type == 'in' ? '+' : '-';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2, bottom: 4),
        padding: const EdgeInsets.all(SsrSpace.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$sign ${draft.amount.toStringAsFixed(0)}'
              '${draft.category == null ? '' : ' · ${draft.category}'}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (draft.note != null) ...[
              const SizedBox(height: 2),
              Text(
                draft.note!,
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
