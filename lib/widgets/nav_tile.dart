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
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: DribTokens.navy,
        ),
      ),
      subtitle: s != null
          ? Text(
              s,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DribTokens.textSecondary,
              ),
            )
          : null,
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

/// Ikon 38x38 kotak pastel plek frame .cat (radius 13, ikon 19).
/// Dipakai hub Profil + sheet mode input.
class _NavIconTile extends StatelessWidget {
  final IconData icon;
  const _NavIconTile(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFE3EEFD),
        borderRadius: BorderRadius.circular(13),
      ),
      child: DuoIcon(icon, color: DribTokens.primaryStrong, size: 19),
    );
  }
}
