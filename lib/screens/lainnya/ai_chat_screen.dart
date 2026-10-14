import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/services/firebase_ai_factory.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';

/// Room chat AI: tanya apa saja, jawab via provider aktif
/// (Gemini -> OpenRouter -> Zen -> Firebase). Riwayat sesi ini saja
/// (memori, tak disimpan). Gagal = bubble jujur.
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
  const _ChatMsg({
    required this.mine,
    required this.text,
    this.provider,
    this.isError = false,
  });
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _items = <_ChatMsg>[];
  final _c = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

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
    return tr(aiMessageKey(e.code));
  }

  Future<void> _send([String? retryText]) async {
    final text = (retryText ?? _c.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _items.add(_ChatMsg(mine: true, text: text));
      _c.clear();
      _sending = true;
    });
    _toBottom();
    try {
      final r = await aiChat(text);
      if (!mounted) return;
      setState(() {
        _items.add(
            _ChatMsg(mine: false, text: r.text, provider: r.provider));
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('chat_title'))),
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
                        return _Bubble(msg: _items[i]);
                      },
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
