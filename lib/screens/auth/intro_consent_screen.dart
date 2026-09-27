import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/auth/theme_step_screen.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/utils/strings.dart';

class IntroConsentScreen extends StatefulWidget {
  final SessionService session;
  final bool skipAuth;
  const IntroConsentScreen({
    super.key,
    required this.session,
    this.skipAuth = false,
  });
  @override
  State<IntroConsentScreen> createState() => _IntroConsentScreenState();
}

class _IntroConsentScreenState extends State<IntroConsentScreen> {
  static const _iconWallet = IconData(0xE68A, fontFamily: SsrFonts.icon);
  static const _iconBell = IconData(0xE5E8, fontFamily: SsrFonts.icon);
  static const _iconUsers = IconData(0xE68E, fontFamily: SsrFonts.icon);
  static const _iconBrain = IconData(0xE74E, fontFamily: SsrFonts.icon);
  static const _iconShield = IconData(0xE40C, fontFamily: SsrFonts.icon);

  final _pageC = PageController();
  int _page = 0;
  bool _agreed = false;
  bool _saving = false;

  static List<String> get _terms => [
    tr('in_term_1'),
    tr('in_term_2'),
    tr('in_term_3'),
    tr('in_term_4'),
    tr('in_term_5'),
  ];

  @override
  void dispose() {
    _pageC.dispose();
    super.dispose();
  }

  void _next() {
    _pageC.nextPage(duration: SsrMotion.base, curve: SsrMotion.curve);
  }

  Future<void> _agree() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('consent_v1', DateTime.now().toIso8601String());
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ThemeStepScreen(
            session: widget.session,
            skipAuth: widget.skipAuth,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('in_save_fail'))));
    }
  }

  Widget _hairline({double width = double.infinity, Color? color}) {
    return Container(
      width: width,
      height: 0.8,
      color: color ?? Theme.of(context).colorScheme.outline,
    );
  }

  Widget _pageShell(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: SsrSpace.xxl,
        vertical: SsrSpace.xl,
      ),
      child: child,
    );
  }

  Widget _iconChip(IconData icon, {double size = 44, Color? bg}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? scheme.outline.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(SsrRadius.tile),
        border: Border.all(color: scheme.outline),
      ),
      child: Icon(icon, size: size * 0.5, color: scheme.primary),
    );
  }

  Widget _pageBrand() {
    return _pageShell(
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: SsrSpace.xxl),
            Text(
              'SSR SPACE',
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(fontSize: 48, letterSpacing: 0),
            ),
            const SizedBox(height: SsrSpace.lg),
            Container(width: 56, height: 1, color: AppColors.gold),
            const SizedBox(height: SsrSpace.xl),
            Text(
              'Simple.',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: SsrSpace.md),
              child: _hairline(width: 140),
            ),
            Text(
              'Secure.',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: SsrSpace.md),
              child: _hairline(width: 140),
            ),
            Text(
              'Reliable.',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: SsrSpace.lg),
            Text(
              'Your Finance Space.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: SsrSpace.xl),
            Text(
              tr('in_brand_sub'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: SsrSpace.xxl),
          ],
        ),
      ),
    );
  }

  Widget _valueRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: t.colorScheme.primary),
          const SizedBox(width: SsrSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.textTheme.titleMedium),
                const SizedBox(height: SsrSpace.xs),
                Text(
                  desc,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageValues() {
    final t = Theme.of(context);
    return _pageShell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('in_values_t'),
            style: t.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(
            tr('in_values_s'),
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: SsrSpace.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SsrSpace.lg),
            decoration: BoxDecoration(
              color: t.colorScheme.surface,
              borderRadius: BorderRadius.circular(SsrRadius.card),
              border: Border.all(color: t.colorScheme.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconChip(_iconBell),
                const SizedBox(width: SsrSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('in_auto_t'), style: t.textTheme.titleMedium),
                      const SizedBox(height: SsrSpace.xs),
                      Text(
                        tr('in_auto_s'),
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: t.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SsrSpace.md),
          _hairline(),
          _valueRow(
            icon: _iconWallet,
            title: tr('in_wallets_t'),
            desc: tr('in_wallets_s'),
          ),
          _hairline(),
          _valueRow(
            icon: _iconUsers,
            title: tr('in_org_t'),
            desc: tr('in_org_s'),
          ),
          _hairline(),
          const SizedBox(height: SsrSpace.xl),
        ],
      ),
    );
  }

  Widget _pageAwareness() {
    final t = Theme.of(context);
    return _pageShell(
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: SsrSpace.xxl),
            Icon(
              _iconBrain,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: SsrSpace.lg),
            Text(
              tr('in_mind_t'),
              textAlign: TextAlign.center,
              style: t.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SsrSpace.lg),
            _hairline(
              width: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: SsrSpace.lg),
            Text(
              tr('in_mind_s1'),
              textAlign: TextAlign.center,
              style: t.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SsrSpace.md),
            Text(
              tr('in_mind_s2'),
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: SsrSpace.xxl),
          ],
        ),
      ),
    );
  }

  Widget _termRow(int i) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${i + 1}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: SsrSpace.sm),
          Expanded(
            child: Text(
              _terms[i],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageTerms() {
    final t = Theme.of(context);
    return _pageShell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconShield,
                size: 26,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: SsrSpace.md),
              Expanded(
                child: Text(
                  tr('in_terms_t'),
                  style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(
            tr('in_terms_s'),
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: SsrSpace.lg),
          for (var i = 0; i < _terms.length; i++) ...[_hairline(), _termRow(i)],
          _hairline(),
          const SizedBox(height: SsrSpace.md),
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Checkbox(
                  value: _agreed,
                  activeColor: t.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: SsrSpace.md),
                    child: Text(tr('in_agree'), style: t.textTheme.titleMedium),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.xl),
        ],
      ),
    );
  }

  Widget _dots() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: SsrSpace.xs),
          AnimatedContainer(
            duration: SsrMotion.fast,
            curve: SsrMotion.curve,
            width: i == _page ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _page ? scheme.primary : scheme.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final onLast = _page == 3;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageC,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _pageBrand(),
                  _pageValues(),
                  _pageAwareness(),
                  _pageTerms(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                SsrSpace.xxl,
                SsrSpace.lg,
                SsrSpace.xxl,
                SsrSpace.lg,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _dots(),
                  const Spacer(),
                  SizedBox(
                    width: 170,
                    child: PrimaryButton(
                      label: onLast ? tr('in_go') : tr('in_next'),
                      loading: _saving,
                      onPressed: onLast ? (_agreed ? _agree : null) : _next,
                    ),
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
