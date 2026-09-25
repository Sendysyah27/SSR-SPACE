import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';
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
          const Icon(Icons.chevron_right, color: SsrColors.secondary),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Ikon 44x44 di atas latar lembut khas tile Lainnya (ukuran ikon 20).
class _NavIconTile extends StatelessWidget {
  final IconData icon;
  const _NavIconTile(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: SsrColors.accentSoft,
        borderRadius: BorderRadius.circular(SsrRadius.tile),
      ),
      child: Icon(icon, color: SsrColors.accent, size: 20),
    );
  }
}
