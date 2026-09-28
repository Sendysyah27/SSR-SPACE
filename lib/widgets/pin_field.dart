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

  Widget _box(BuildContext context, int i, bool filled) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 40,
      decoration: BoxDecoration(
        color: filled
            ? scheme.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(SsrRadius.input),
        border: Border.all(
          color: widget.error != null
              ? scheme.error
              : filled
                  ? scheme.primary
                  : scheme.outline.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        filled ? (widget.obscure ? '•' : widget.controller.text[i]) : '',
        style: TextStyle(
          fontFamily: SsrFonts.numeric,
          fontSize: 16,
          fontWeight: FontWeight.w600,
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
            if (i > 0) const SizedBox(width: 6),
            _box(context, i, i < text.length),
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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focus.requestFocus(),
          child: SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  autofocus: widget.autofocus,
                  obscureText: widget.obscure,
                  enableInteractiveSelection: false,
                  cursorColor: Colors.transparent,
                  decoration: const InputDecoration.collapsed(hintText: ''),
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontFamily: SsrFonts.numeric,
                    fontSize: 16,
                  ),
                ),
                IgnorePointer(child: _boxesRow(context, text)),
              ],
            ),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
