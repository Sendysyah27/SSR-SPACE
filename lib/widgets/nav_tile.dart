import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/widgets/status_chip.dart';

/// Baris menu "Lainnya": ikon + judul (+ subjudul & chip status) + chevron.
/// Satu-satunya tempat pola ini dipakai: layar Lainnya (other_screen).
class NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final StatusChip? chip;
  final VoidCallback? onTap;

  const NavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.chip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = chip;
    final s = subtitle;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _NavIconTile(icon),
      title: Text(title),
      subtitle: s != null ? Text(s) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c != null) ...[c, const SizedBox(width: SsrSpace.sm)],
          DuoIcon(
            AppIcons.chevron,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Ikon 44x44 di atas latar pastel biru khas tile (ukuran ikon 20).
/// TAHAP 8: dipakai hub Profil + sheet mode input.
class _NavIconTile extends StatelessWidget {
  final IconData icon;
  const _NavIconTile(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: DribTokens.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DuoIcon(icon, color: DribTokens.primary, size: 20),
    );
  }
}
