import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Bus tunggal untuk `overlayListener` plugin (stream sekali-dengar).
///
/// MainShell lahir berkali-kali seumur app (mis. `pushReplacement` saat
/// ganti workspace): listen langsung ke plugin dari tiap initState berarti
/// dua subscription hidup bersamaan sesaat (initState baru jalan sebelum
/// dispose lama) → "Bad state: Stream has already been listened to" dan
/// route abu total. Bus ini subscribe ke plugin MAKSIMAL sekali; layar
/// hanya daftar/hapus callback.
class OverlayBus {
  static StreamSubscription? _sub;
  static final _listeners = <String, void Function(Object?)>{};

  static void add(String key, void Function(Object?) cb) {
    _listeners[key] = cb;
    _ensure();
  }

  static void remove(String key) {
    _listeners.remove(key);
  }

  static void _ensure() {
    if (_sub != null) return;
    try {
      _sub = FlutterOverlayWindow.overlayListener.listen(
        (event) {
          for (final cb in _listeners.values.toList()) {
            try {
              cb(event);
            } catch (e) {
              debugPrint('overlay bus cb: $e');
            }
          }
        },
        onError: (Object e) => debugPrint('overlay bus: $e'),
      );
    } catch (e) {
      debugPrint('overlay bus listen: $e');
      _sub = null;
    }
  }
}
