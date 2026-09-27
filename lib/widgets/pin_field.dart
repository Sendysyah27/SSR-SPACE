import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ssr_space/theme/app_theme.dart';

class PinField extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final String? error;
  final ValueChanged<String>? onCompleted;
  final bool obscure;
  final bool autofocus;

  const PinField({
    super.key,
    required this.controller,
    this.length = 6,
    this.error,
    this.onCompleted,
    this.obscure = true,
    this.autofocus = false,
  });

  @override
  State<PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<PinField> {
  late final FocusNode _focus;

  /// Guard sekali-tembak: listener (teks + fokus) bisa fire berkali-kali
  /// saat teks sudah penuh (mis. keyboard turun → focus berubah setelah
  /// dialog sukses dipop). Tanpa ini onCompleted jalan ganda → pop ganda →
  /// route aplikasi ikut ter-pop (layar hitam, back mati).
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
    final v = widget.controller.text;
    if (v.length < widget.length) {
      _fired = false;
      return;
    }
    if (_fired) return;
    _fired = true;
    widget.onCompleted?.call(v);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  Widget _box(BuildContext context, int i, bool filled, bool isCurrent) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: 38,
      height: 46,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.error != null
              ? AppColors.rust
              : isCurrent || filled
              ? AppColors.emerald
              : scheme.outline,
          width: isCurrent ? 2 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        filled ? (widget.obscure ? '•' : widget.controller.text[i]) : '',
        style: TextStyle(
          fontFamily: SsrFonts.numeric,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
    );
  }

  Widget _boxesRow(BuildContext context, String text) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _box(
              context,
              i,
              i < text.length,
              i == text.length && _focus.hasFocus,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 46,
          child: Stack(
            children: [
              Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  autofocus: widget.autofocus,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _focus.requestFocus(),
                child: _boxesRow(context, text),
              ),
            ],
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.error!,
            style: const TextStyle(color: AppColors.rust, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
