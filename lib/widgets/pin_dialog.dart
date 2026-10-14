import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/pin_field.dart';
import 'package:ssr_space/widgets/pin_pad.dart';
import 'package:ssr_space/widgets/premium/glass_sheet.dart';

/// Dialog PIN bersama (dipakai danger zone workspace detail dkk).
/// true bila PIN benar; false bila batal/salah.
Future<bool> askPinDialog(BuildContext context) async {
  final pinC = TextEditingController();
  try {
    String? err;
    return await showGlassDialog<bool>(
          context: context,
          title: Text(tr('b_pin_title')),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (ctx, setD) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('b_pin_body')),
                  const SizedBox(height: SsrSpace.md),
                  PinField(
                    controller: pinC,
                    length: 6,
                    error: err,
                    onCompleted: (_) =>
                        _submitPin(ctx, setD, pinC, (String? e) => err = e),
                  ),
                  const SizedBox(height: SsrSpace.md),
                  PinPad(controller: pinC, length: 6),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel')),
            ),
          ],
        ) ??
        false;
  } finally {
    pinC.dispose();
  }
}

Future<void> _submitPin(
  BuildContext ctx,
  StateSetter setD,
  TextEditingController pinC,
  void Function(String? err) setErr,
) async {
  final ok = await SessionService(await SharedPreferences.getInstance())
      .verifyPin(pinC.text);
  if (!ctx.mounted) return;
  if (ok) {
    Navigator.pop(ctx, true);
    return;
  }
  pinC.clear();
  setD(() => setErr(tr('b_pin_wrong')));
}
