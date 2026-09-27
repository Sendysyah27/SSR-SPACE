import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:ssr_space/theme/app_theme.dart';

/// Rangka loading meniru bentuk konten tiap layar.
class _Zone extends StatelessWidget {
  final List<Widget> children;
  const _Zone(this.children);

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      enabled: true,
      effect: const ShimmerEffect(
        baseColor: SsrColors.noirRaised,
        highlightColor: SsrColors.noirLine,
      ),
      child: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: children,
      ),
    );
  }
}

Widget _rowBone() {
  return const Padding(
    padding: EdgeInsets.symmetric(vertical: SsrSpace.sm),
    child: Row(
      children: [
        Bone.circle(size: 44),
        SizedBox(width: SsrSpace.md),
        Expanded(child: Bone.multiText(lines: 2)),
      ],
    ),
  );
}

Widget _cardBone(double height) {
  return Padding(
    padding: const EdgeInsets.only(bottom: SsrSpace.md),
    child: Bone(height: height, uniRadius: SsrRadius.card),
  );
}

class BerandaSkeleton extends StatelessWidget {
  const BerandaSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Zone([
      _cardBone(220),
      const SizedBox(height: SsrSpace.sm),
      const Bone(height: 48, uniRadius: SsrRadius.button),
      const SizedBox(height: SsrSpace.sm),
      _rowBone(),
      _rowBone(),
      _rowBone(),
    ]);
  }
}

class TxListSkeleton extends StatelessWidget {
  const TxListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Zone([
      _cardBone(300),
      const SizedBox(height: SsrSpace.sm),
      _rowBone(),
      _rowBone(),
      _rowBone(),
      _rowBone(),
    ]);
  }
}

class BudgetListSkeleton extends StatelessWidget {
  const BudgetListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Zone([_cardBone(120), _cardBone(120), _cardBone(200)]);
  }
}

class ReportSkeleton extends StatelessWidget {
  const ReportSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Zone([
      const Center(child: Bone.circle(size: 160)),
      const SizedBox(height: SsrSpace.md),
      _cardBone(76),
      _cardBone(76),
      _rowBone(),
      _rowBone(),
    ]);
  }
}

class WalletListSkeleton extends StatelessWidget {
  const WalletListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Zone([_cardBone(96), _cardBone(190), _rowBone(), _rowBone()]);
  }
}

class InviteListSkeleton extends StatelessWidget {
  const InviteListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Zone([_cardBone(170), _rowBone(), _rowBone()]);
  }
}

class NotifSettingsSkeleton extends StatelessWidget {
  const NotifSettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Zone([_cardBone(150), _cardBone(220), _cardBone(120)]);
  }
}
