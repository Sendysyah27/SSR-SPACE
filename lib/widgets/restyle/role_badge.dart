import 'package:flutter/material.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Badge peran kecil gaya chip frame mockup: pill penuh, teks 10.5 w800.
///
/// Pemilik = chip ok hijau; penonton = chip abu; peran lain = chip biru
/// muda; pending/undangan = oranye aksen (teks navy demi kontras AA).
class RoleBadge extends StatelessWidget {
  final String role;
  final String? roleKey;

  const RoleBadge({super.key, required this.role, this.roleKey});

  bool get _isPending {
    final r = role.trim().toLowerCase();
    return r == 'pending' ||
        r == 'invited' ||
        r == 'undangan' ||
        r == 'menunggu';
  }

  @override
  Widget build(BuildContext context) {
    final key = (roleKey ?? '').trim().toLowerCase();
    final Color bg;
    final Color fg;
    if (_isPending) {
      // Kontras AA: putih di atas oranye hanya 2.02 -> teks navy (7.05).
      bg = DribTokens.accentOrange;
      fg = DribTokens.navy;
    } else if (key == 'owner') {
      bg = const Color(0xFFD9F5E9);
      fg = DribTokens.successText;
    } else if (key == 'viewer' || key == 'penonton') {
      bg = const Color(0xFFEDF1F8);
      fg = DribTokens.textSecondary;
    } else {
      bg = const Color(0xFFE3EEFD);
      fg = DribTokens.primaryStrong;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
