import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_ai_parser.dart';

// Model parser struk: flash-tier hemat, stabil, hidup >= 2027-05-19.
// (gemini-2.0-flash mati 2026-06-01.) Ganti 1 const ini bila perlu.
// API terverifikasi docs Firebase AI Logic + firebase_ai 4.0.0.
const firebaseAiModel = 'gemini-3.5-flash';

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

/// Bangun [AiGenerate] dari model Firebase, atau null bila AI tak bisa
/// dipakai (Firebase belum init / user belum login Google / error apa
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
        final m = e.toString().toLowerCase();
        if (m.contains('permission-denied') ||
            m.contains('unauthenticated') ||
            m.contains('quota') ||
            m.contains('403') ||
            m.contains('api key')) {
          throw const AiDenied();
        }
        rethrow;
      }
    };
  } catch (_) {
    return null;
  }
}
