import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ssr_space/services/wallet_brand.dart';
import 'package:ssr_space/theme/app_icons.dart';

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

  /// Nama dompet: bila cocok brand, tampil badge monogram warna brand.
  final String? name;

  const WalletArt(this.type, {super.key, this.size = 22, this.name});

  @override
  Widget build(BuildContext context) {
    final brand = brandForWallet(name);
    if (brand != null) return _BrandBadge(brand: brand, size: size);
    final scheme = Theme.of(context).colorScheme;
    return SvgPicture.asset(
      walletSvgPath(type),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.outline,
        ),
        child: DuoIcon(
          AppIcons.walletCash,
          size: size * 0.7,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// Badge monogram brand: kotak warna brand + 1-4 huruf putih tebal.
class _BrandBadge extends StatelessWidget {
  final WalletBrand brand;
  final double size;

  const _BrandBadge({required this.brand, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(brand.argb),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Text(
          brand.short,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * (brand.short.length > 2 ? 0.26 : 0.34),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
