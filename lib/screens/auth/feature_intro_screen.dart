import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/drib_card.dart';
import 'package:ssr_space/widgets/restyle/budget_progress_bar.dart';
import 'package:ssr_space/widgets/restyle/donut_chart.dart';
import 'package:ssr_space/widgets/restyle/swipe_to_confirm.dart';

/// Kunci flag: intro fitur terbaru sudah tampil sekali.
const introSeenKey = 'intro_v1';

Future<bool> introSeen() async {
  try {
    final v =
        (await SharedPreferences.getInstance()).getString(introSeenKey);
    return v != null && v.isNotEmpty;
  } catch (_) {
    return true;
  }
}

Future<void> markIntroSeen() async {
  try {
    await (await SharedPreferences.getInstance()).setString(
      introSeenKey,
      DateTime.now().toIso8601String(),
    );
  } catch (_) {}
}

/// Intro fitur terbaru: carousel 4 slide, sekali saja.
/// Dipanggil splash untuk user baru maupun lama yang belum lihat.
class FeatureIntroScreen extends StatefulWidget {
  final VoidCallback onDone;
  const FeatureIntroScreen({super.key, required this.onDone});

  @override
  State<FeatureIntroScreen> createState() => _FeatureIntroScreenState();
}

class _FeatureIntroScreenState extends State<FeatureIntroScreen> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markIntroSeen();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    const slides = [_SlideDonut(), _SlideBudget(), _SlideChat(), _SlideSwipe()];
    return Scaffold(
      backgroundColor: DribTokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(tr('fi_skip')),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (v) => setState(() => _i = v),
                children: slides,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var d = 0; d < slides.length; d++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d == _i
                          ? DribTokens.primary
                          : DribTokens.navy.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: DribTokens.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    if (_i >= slides.length - 1) {
                      _finish();
                    } else {
                      _page.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(
                    _i >= slides.length - 1
                        ? tr('fi_done')
                        : tr('fi_next'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SlideShell extends StatelessWidget {
  final String title;
  final String sub;
  final Widget demo;
  const _SlideShell({
    required this.title,
    required this.sub,
    required this.demo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          demo,
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: DribTokens.navy),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SlideDonut extends StatelessWidget {
  const _SlideDonut();

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: tr('fi_t1'),
      sub: tr('fi_s1'),
      demo: DribCard(
        child: DonutChart(
          centerText: '40%',
          slices: const [
            DonutSlice(value: 40, label: 'Masuk', color: DribTokens.primary),
            DonutSlice(value: 35, label: 'Belanja', color: DribTokens.navy),
            DonutSlice(
                value: 25, label: 'Tabungan', color: DribTokens.accentOrange),
          ],
        ),
      ),
    );
  }
}

class _SlideBudget extends StatelessWidget {
  const _SlideBudget();

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: tr('fi_t2'),
      sub: tr('fi_s2'),
      demo: const DribCard(
        child: BudgetProgressBar(progress: 0.65, label: '65%'),
      ),
    );
  }
}

class _SlideChat extends StatelessWidget {
  const _SlideChat();

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: tr('fi_t3'),
      sub: tr('fi_s3'),
      demo: DribCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DribTokens.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: DribTokens.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('fi_chat_ex'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideSwipe extends StatelessWidget {
  const _SlideSwipe();

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: tr('fi_t4'),
      sub: tr('fi_s4'),
      demo: SwipeToConfirmButton(
        label: tr('fi_swipe_ex'),
        onConfirm: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('fi_swipe_ok'))),
          );
        },
      ),
    );
  }
}
