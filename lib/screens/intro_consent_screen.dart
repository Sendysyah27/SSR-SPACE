import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/screens/splash_screen.dart';
import 'package:ssr_space/widgets/primary_button.dart';

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

  static const _ruleColor = Color(0xFFD9D7D0);

  final _pageC = PageController();
  int _page = 0;
  bool _agreed = false;
  bool _saving = false;

  static const _terms = [
    'SSR SPACE alat pencatat. Tanggung jawab keputusan keuangan tetap di tanganmu.',
    'Data disimpan aman di cloud dan hanya bisa diakses dalam workspace-mu.',
    'Pelacakan otomatis butuh izin akses notifikasi. Kamu bisa mematikannya kapan saja.',
    'PIN dan password adalah tanggung jawabmu. Jangan dibagikan ke siapa pun.',
    'Aplikasi ini bukan nasihat keuangan atau kebijakan investasi.',
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
          builder: (_) =>
              SplashScreen(session: widget.session, skipAuth: widget.skipAuth),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan persetujuan. Coba lagi.'),
        ),
      );
    }
  }

  Widget _hairline({double width = double.infinity, Color color = _ruleColor}) {
    return Container(width: width, height: 0.8, color: color);
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? Colors.white,
        borderRadius: BorderRadius.circular(SsrRadius.tile),
      ),
      child: Icon(icon, size: size * 0.5, color: SsrColors.accent),
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
            Container(width: 56, height: 2, color: SsrColors.accent),
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
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: SsrColors.accent),
            ),
            const SizedBox(height: SsrSpace.xl),
            Text(
              'Buku kas harian yang tenang, rapi, dan bisa dipercaya.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: SsrColors.secondary),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: SsrColors.accent),
          const SizedBox(width: SsrSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: SsrSpace.xs),
                Text(
                  desc,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: SsrColors.secondary),
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
            'Semua urusan uang, satu ruang',
            style: t.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(
            'Tiga hal yang bikin catatan harian terasa ringan.',
            style: t.textTheme.bodyMedium?.copyWith(color: SsrColors.secondary),
          ),
          const SizedBox(height: SsrSpace.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SsrSpace.lg),
            decoration: BoxDecoration(
              color: SsrColors.accentSoft,
              borderRadius: BorderRadius.circular(SsrRadius.card),
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
                      Text(
                        'Catatan otomatis dari notifikasi',
                        style: t.textTheme.titleMedium,
                      ),
                      const SizedBox(height: SsrSpace.xs),
                      Text(
                        'Notifikasi bank dan e-wallet terbaca jadi '
                        'transaksi. Kamu tinggal cek, bukan ketik ulang.',
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: SsrColors.secondary,
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
            title: 'Dompet multi',
            desc:
                'Kas, bank, dan e-wallet. Tiap dompet punya saldo '
                'sendiri, semuanya rapi dalam satu buku kas.',
          ),
          _hairline(),
          _valueRow(
            icon: _iconUsers,
            title: 'Workspace bersama',
            desc:
                'Satu buku kas bisa dipakai bareng pasangan atau tim, '
                'lewat undangan aman.',
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
            const Icon(_iconBrain, size: 40, color: SsrColors.accent),
            const SizedBox(height: SsrSpace.lg),
            Text(
              'Kelola keuangan dengan sadar',
              textAlign: TextAlign.center,
              style: t.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SsrSpace.lg),
            _hairline(width: 80, color: SsrColors.accent),
            const SizedBox(height: SsrSpace.lg),
            Text(
              'SSR SPACE mencatat, kamu yang memutuskan.',
              textAlign: TextAlign.center,
              style: t.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SsrSpace.md),
            Text(
              'Aplikasi ini membantu kamu melihat ke mana uangmu pergi. '
              'Setiap angka berasal dari catatanmu sendiri, jadi keputusan '
              'tetap di tanganmu. Data yang jujur hari ini jadi laporan '
              'yang akurat bulan depan.',
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium?.copyWith(
                color: SsrColors.secondary,
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
                color: SsrColors.accent,
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
              const Icon(_iconShield, size: 26, color: SsrColors.accent),
              const SizedBox(width: SsrSpace.md),
              Expanded(
                child: Text(
                  'Syarat & persetujuan',
                  style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(
            'Baca sekali, setujui untuk mulai mencatat.',
            style: t.textTheme.bodyMedium?.copyWith(color: SsrColors.secondary),
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
                  activeColor: SsrColors.accent,
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
                    child: Text(
                      'Saya paham dan setuju',
                      style: t.textTheme.titleMedium,
                    ),
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
              color: i == _page ? SsrColors.accent : SsrColors.surfaceMuted,
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
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _ruleColor)),
              ),
              child: Row(
                children: [
                  _dots(),
                  const Spacer(),
                  SizedBox(
                    width: 170,
                    child: PrimaryButton(
                      label: onLast ? 'Setuju & mulai' : 'Lanjut',
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
