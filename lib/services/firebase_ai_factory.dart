import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_ai_parser.dart';

// Model parser struk: alias stabil resmi Firebase AI Logic — selalu ikut
// flash stabil terbaru (tanpa ganti kode tiap rilis model).
// Docs: agent-skills flutter_setup.md + pola versi Gemini API.
const firebaseAiModel = 'gemini-flash-latest';

// Sakelar AI Parser (prefs biasa, default ON — tanpa kunci = langsung
// jalan bila login Google). Tanpa prefs (error) = ON (fail-open).
const _kAiEnabled = 'ai_enabled';

Future<bool> aiEnabled() async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAiEnabled) ?? true;
  } catch (_) {
    return true;
  }
}

Future<void> setAiEnabled(bool v) async {
  try {
    await (await SharedPreferences.getInstance()).setBool(_kAiEnabled, v);
  } catch (_) {}
}

/// Pastikan ada sesi Firebase Auth (syarat AI parser), untuk SEMUA cara
/// login Supabase — bukan cuma Google. Urutan: sesi ada → true;
/// ada idToken Google → link credential; selain itu → anonim.
/// Tak pernah throw (false = AI mati, app tetap jalan).
/// Catatan: anonim butuh provider Anonymous ON di Firebase console;
/// bila mati = false (fail-open, bukan crash).
Future<bool> ensureFirebaseSession({
  String? idToken,
  String? accessToken,
}) async {
  try {
    if (FirebaseAuth.instance.currentUser != null) return true;
    if (idToken != null && idToken.isNotEmpty) {
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: accessToken,
        ),
      );
    } else {
      await FirebaseAuth.instance.signInAnonymously();
    }
    return FirebaseAuth.instance.currentUser != null;
  } catch (_) {
    return false;
  }
}

/// Bangun [AiGenerate] dari model Firebase, atau null bila AI tak bisa
/// dipakai (Firebase belum init / tanpa sesi Firebase / error apa
/// pun). Tak pernah throw — pemanggil diam bila null.
Future<AiGenerate?> firebaseAiGenerate() async {
  try {
    if (FirebaseAuth.instance.currentUser == null) return null;
    final model = FirebaseAI.googleAI().generativeModel(
      model: firebaseAiModel,
    );
    return (prompt) async {
      try {
        final res = await model.generateContent([Content.text(prompt)]);
        return res.text;
      } catch (e) {
        // Log lengkap untuk diagnosis via `adb logcat` (tak diupload).
        debugPrint('firebase ai gagal: $e');
        final m = e.toString().toLowerCase();
        if (m.contains('permission-denied') ||
            m.contains('unauthenticated') ||
            m.contains('quota') ||
            m.contains('403') ||
            m.contains('api key')) {
          throw AiDenied(e.toString());
        }
        rethrow;
      }
    };
  } catch (_) {
    return null;
  }
}
