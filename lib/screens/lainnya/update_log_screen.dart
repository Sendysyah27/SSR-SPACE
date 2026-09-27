import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';

/// Catatan perubahan: baca aset teks statis, tanpa paket markdown.
class UpdateLogScreen extends StatefulWidget {
  const UpdateLogScreen({super.key});

  @override
  State<UpdateLogScreen> createState() => _UpdateLogScreenState();
}

class _UpdateLogScreenState extends State<UpdateLogScreen> {
  Future<String>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<String> _load() async {
    try {
      return await rootBundle.loadString('assets/changelog_id.md');
    } catch (_) {
      rethrow;
    }
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('ab_changelog'))),
      body: FutureBuilder<String>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return _LogError(onRetry: _retry);
          }
          return _LogBody(text: snap.data ?? '');
        },
      ),
    );
  }
}

/// Status galat baca aset plus tombol coba lagi.
class _LogError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LogError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SsrSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('w_err_load'),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SsrSpace.md),
            OutlinedButton(onPressed: onRetry, child: Text(tr('retry'))),
          ],
        ),
      ),
    );
  }
}

/// Isi log sebagai teks polos yang bisa digulir.
class _LogBody extends StatelessWidget {
  final String text;

  const _LogBody({required this.text});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
