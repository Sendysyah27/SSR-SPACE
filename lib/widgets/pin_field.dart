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
    if (v.length >= widget.length) {
      widget.onCompleted?.call(v);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  Widget _box(int i, bool filled, bool isCurrent) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(SsrRadius.input),
          border: Border.all(
            color: widget.error != null
                ? SsrColors.danger
                : isCurrent || filled
                ? SsrColors.accent
                : const Color(0xFFD9D7D0),
            width: isCurrent ? 1.8 : 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          filled ? (widget.obscure ? '•' : widget.controller.text[i]) : '',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: SsrColors.ink,
          ),
        ),
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
          height: 52,
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
                child: Row(
                  children: [
                    for (var i = 0; i < widget.length; i++)
                      _box(
                        i,
                        i < text.length,
                        i == text.length && _focus.hasFocus,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.error!,
            style: const TextStyle(color: SsrColors.danger, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
