import 'package:flutter/material.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Badge peran kecil TAHAP 3 (baru, belum dipakai layar).
///
/// Oranye [DribTokens.accentOrange] KHUSUS pending/undangan; peran lain
/// navy lembut. Tanpa teks peran tak dikenal = tampil apa adanya.
class RoleBadge extends StatelessWidget {
  final String role;

  const RoleBadge({super.key, required this.role});

  bool get _isPending {
    final r = role.trim().toLowerCase();
    return r == 'pending' ||
        r == 'invited' ||
        r == 'undangan' ||
        r == 'menunggu';
  }

  @override
  Widget build(BuildContext context) {
    // Kontras AA: putih di atas oranye hanya 2.02 -> teks selalu navy
    // (navy/oranye 7.05, navy/navy-8% ~10).
    const fg = DribTokens.navy;
    final bg = _isPending
        ? DribTokens.accentOrange
        : DribTokens.navy.withValues(alpha: 0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
