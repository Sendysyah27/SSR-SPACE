import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/offline_cache.dart';
import 'package:ssr_space/services/quick_input_parse.dart';
import 'package:ssr_space/services/voice_native.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/entry/voice_draft_sheet.dart';

/// Bottom sheet dengar suara gaya Ollo. Dibuka -> langsung mulai listening
/// memakai [VoiceNative] + parser existing (tanpa ubah recognition/parsing).
/// Stop & Proses -> parse -> kembalikan [VoiceDraft]; gagal -> pesan error +
/// tombol Coba Lagi.
Future<VoiceDraft?> showVoiceListeningSheet(BuildContext context) {
  return showModalBottomSheet<VoiceDraft?>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceListeningSheet(),
  );
}

enum _Phase { init, listening, error }

class _VoiceListeningSheet extends StatefulWidget {
  const _VoiceListeningSheet();

  @override
  State<_VoiceListeningSheet> createState() => _VoiceListeningSheetState();
}

class _VoiceListeningSheetState extends State<_VoiceListeningSheet>
    with SingleTickerProviderStateMixin {
  final _voice = VoiceNative();
  _Phase _phase = _Phase.init;
  String _errKey = '';
  String _words = '';
  List<String> _walletNames = const [];
  bool _busy = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _prepare();
  }

  @override
  void dispose() {
    _voice.stop();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final orgId = await activeOrgId();
      if (orgId.isNotEmpty) {
        final ws = await WalletService().list(orgId);
        _walletNames = ws.map((w) => w.name).toList();
      }
    } catch (_) {}
    if (!mounted) return;
    if (!netOnline.value) {
      _fail('vc_offline');
      return;
    }
    PermissionStatus st;
    try {
      st = await Permission.microphone.request();
    } catch (_) {
      if (mounted) _fail('vc_error');
      return;
    }
    if (!mounted) return;
    if (!st.isGranted) {
      _fail('vc_denied');
      return;
    }
    final ok = await _voice.isAvailable();
    if (!mounted) return;
    if (!ok) {
      _fail('vc_error');
      return;
    }
    _startListening();
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.listening;
      _errKey = '';
      _words = '';
    });
    var started = false;
    for (final attempt in voiceLocaleAttempts('id-ID')) {
      if (!mounted) break;
      started = await _voice.start(
        localeId: attempt,
        onResult: (words, _) {
          if (mounted) setState(() => _words = words);
        },
        onError: (code) {
          if (mounted) _fail(voiceErrorKey(code));
        },
        onStatus: (s) {
          if (mounted && s == 'done' && _words.trim().isEmpty) {
            _fail('vc_hear');
          }
        },
      );
      if (started) break;
    }
    if (!started && mounted && _phase == _Phase.listening) {
      _fail('vc_error');
    }
  }

  void _fail(String key) {
    if (!mounted) return;
    _voice.stop();
    setState(() {
      _phase = _Phase.error;
      _errKey = key;
    });
  }

  Future<void> _onStop() async {
    if (_busy) return;
    _busy = true;
    await _voice.stop();
    if (!mounted) {
      _busy = false;
      return;
    }
    final text = normalizeSpoken(_words);
    final q = text.isEmpty
        ? null
        : parseQuickInput(
            text,
            categories: appCategories.value,
            wallets: _walletNames,
          );
    _busy = false;
    if (!mounted) return;
    if (q == null) {
      // Tak terurai -> tampilkan error + tombol jadi "Coba Lagi".
      _fail('voice_err_empty');
      return;
    }
    final title = q.note.isNotEmpty ? q.note : (q.category ?? '');
    Navigator.of(context).pop(VoiceDraft(
      amount: q.amount,
      type: q.type == 'in' ? 'in' : 'out',
      category: q.category,
      walletName: q.walletName,
      title: title,
      dateTime: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const micBlue = Color(0xFF5B9BF5);
    return Container(
      decoration: BoxDecoration(
        color: DribTokens.cardOf(context),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DribTokens.sheetRadius),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: scheme.outlineVariant,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tr('voice_listen_title'),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.06).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: micBlue.withValues(alpha: 0.15),
              ),
              alignment: Alignment.center,
              child: const Icon(AppIcons.voice, size: 44, color: micBlue),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('voice_listen_hint'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.public, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                tr('voice_input_lang'),
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          if (_phase == _Phase.error) ...[
            const SizedBox(height: 10),
            Text(
              tr(_errKey),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.error),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.inverseSurface,
                foregroundColor: scheme.onInverseSurface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _phase == _Phase.listening
                  ? _onStop
                  : (_phase == _Phase.error ? _prepare : null),
              child: Text(
                _phase == _Phase.error ? tr('voice_retry') : tr('voice_stop'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
