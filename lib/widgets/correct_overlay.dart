import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:ssr_space/theme/app_theme.dart';

/// Isi overlay koreksi instan: ringkasan + Lengkapi/Tutup.
/// Berjalan di isolate overlay; data masuk via shareData ({tx,title,body,ok,no}).
/// Menutup sendiri setelah 30 detik.
class CorrectOverlay extends StatefulWidget {
  const CorrectOverlay({super.key});

  @override
  State<CorrectOverlay> createState() => CorrectOverlayState();
}

class CorrectOverlayState extends State<CorrectOverlay> {
  String title = '…';
  String body = '…';
  String ok = '…';
  String no = '…';
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen((event) {
      try {
        final m = jsonDecode('$event') as Map<String, dynamic>;
        final b = (m['body'] ?? '').toString();
        if (b.isEmpty || !mounted) return;
        setState(() {
          title = (m['title'] ?? '').toString();
          body = b;
          ok = (m['ok'] ?? '').toString();
          no = (m['no'] ?? '').toString();
        });
      } catch (_) {}
    });
    Timer(const Duration(seconds: 30), () {
      FlutterOverlayWindow.closeOverlay();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _act(String msg) async {
    try {
      await FlutterOverlayWindow.shareData(msg);
    } catch (_) {}
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 48),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SsrColors.noirRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SsrColors.noirLine),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SsrColors.noirInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 15,
                  color: SsrColors.noirInk,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _act('tutup'),
                    style: TextButton.styleFrom(
                      foregroundColor: SsrColors.mint,
                    ),
                    child: Text(no),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _act('lengkapi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SsrColors.mint,
                      foregroundColor: SsrColors.noirBg,
                    ),
                    child: Text(ok),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
