import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: AppColors.cream,
          disabledBackgroundColor:
              AppColors.emerald.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.cream.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsrRadius.button),
          ),
          textStyle: const TextStyle(
            fontFamily: SsrFonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: loading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : Text(label, key: ValueKey(label)),
        ),
      ),
    );
  }
}
