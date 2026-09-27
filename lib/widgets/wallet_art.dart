import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';

/// Ikon dompet per tipe dari SVG redrawn (P2 wallet-svg-pack).
/// Gaya garis 1.5px, warna via colorFilter (file tanpa warna hardcode).
/// Tipe tak dikenal -> cash. File hilang -> lingkaran fallback.
String walletSvgPath(String type) {
  switch (type) {
    case 'bank':
      return 'assets/illustrations/wallet_bank.svg';
    case 'ewallet':
      return 'assets/illustrations/wallet_ewallet.svg';
    default:
      return 'assets/illustrations/wallet_cash.svg';
  }
}

class WalletArt extends StatelessWidget {
  final String type;
  final double size;

  const WalletArt(this.type, {super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      walletSvgPath(type),
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(SsrColors.mint, BlendMode.srcIn),
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: SsrColors.noirLine,
        ),
        child: DuoIcon(
          AppIcons.walletCash,
          size: size * 0.7,
          color: SsrColors.mint,
        ),
      ),
    );
  }
}
