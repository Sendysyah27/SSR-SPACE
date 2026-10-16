import 'package:flutter/material.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Avatar tumpuk horizontal + nama TAHAP 3 (baru, belum dipakai layar).
///
/// Untuk daftar anggota pola baru (inisial dari nama; tanpa foto).
class MemberAvatarRow extends StatelessWidget {
  /// Nama anggota tampil.
  final List<String> names;

  /// Warna latar avatar per anggota (diputar bila kurang).
  final List<Color> palette;

  /// Maksimal avatar tampil; sisanya jadi "+n".
  final int maxShown;

  const MemberAvatarRow({
    super.key,
    required this.names,
    this.palette = const [
      DribTokens.primary,
      DribTokens.navyBright,
      DribTokens.accentOrange,
    ],
    this.maxShown = 5,
  });

  /// Inisial 1–2 huruf dari nama.
  static String initialsOf(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final shown = names.take(maxShown).toList();
    final rest = names.length - shown.length;
    return Row(
      children: [
        SizedBox(
          height: 32,
          width: shown.isEmpty
              ? 0
              : 24.0 + shown.length * 24.0 + (rest > 0 ? 28.0 : 0.0),
          child: Stack(
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * 24.0,
                  child: _Avatar(
                    initials: initialsOf(shown[i]),
                    color: palette[i % palette.length],
                  ),
                ),
              if (rest > 0)
                Positioned(
                  left: shown.length * 24.0,
                  child: _Avatar(
                    initials: '+$rest',
                    color: DribTokens.navy.withValues(alpha: 0.15),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            names.join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final Color color;
  const _Avatar({required this.initials, required this.color});

  /// Kontras AA: putih hanya di atas navy (10.19); di atas biru/oranye
  /// muda pakai teks navy (5.05 / 7.05).
  bool get _lightText {
    if (color == DribTokens.navy || color == DribTokens.navyBright) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: DribTokens.card, width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: _lightText ? Colors.white : DribTokens.navy,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
