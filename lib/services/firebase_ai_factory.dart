import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import 'firebase_ai_parser.dart';

// Model parser struk: alias stabil resmi Firebase AI Logic — selalu ikut
// flash stabil terbaru (tanpa ganti kode tiap rilis model).
// Docs: agent-skills flutter_setup.md + pola versi Gemini API.
const firebaseAiModel = 'gemini-flash-latest';

// Kunci API Android dari google-services.json (disuntik CI via
// dart-define GOOGLE_API_KEY; kosong = tanpa REST fallback).
// Dipakai HANYA untuk Plan B REST langsung ke Gemini Developer API.
const googleApiKey = String.fromEnvironment('GOOGLE_API_KEY',
    defaultValue: '');

const _restTimeout = Duration(seconds: 30);

/// Plan B: POST langsung ke Gemini Developer API bila SDK hang.
/// Return teks, atau null (gagal = pemanggil tentukan vonis).
/// Tak pernah throw.
Future<String?> _restGenerate(String prompt) async {
  if (googleApiKey.isEmpty) return null;
  final client = http.Client();
  try {
    final res = await client
        .post(
          Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$firebaseAiModel:generateContent'),
          headers: {
            'x-goog-api-key': googleApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(restPromptBody(prompt)),
        )
        .timeout(_restTimeout);
    debugPrint('firebase ai rest status ${res.statusCode}');
    if (res.statusCode != 200) return null;
    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      return null;
    }
    return parseRestText(body);
  } catch (e) {
    debugPrint('firebase ai rest gagal: $e');
    return null;
  } finally {
    client.close();
  }
}

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
        debugPrint('firebase ai sdk generateContent mulai...');
        // Timeout di DALAM closure agar on TimeoutException di bawah
        // (→ REST) yang menang, bukan timeout luar parser.
        final res = await model
            .generateContent([Content.text(prompt)])
            .timeout(firebaseAiTimeout);
        debugPrint('firebase ai sdk generateContent selesai.');
        return res.text;
      } on TimeoutException {
        // SDK hang: Plan B REST langsung (30 dtk). Sukses = pakai;
        // gagal = vonis timeout jujur (tanpa retry ganda pemanggil).
        debugPrint('firebase ai sdk hang, coba REST...');
        final t = await _restGenerate(prompt);
        if (t != null && t.trim().isNotEmpty) return t;
        throw const AiFailure('timeout', 'sdk hang + rest gagal');
      } catch (e) {
        // Log lengkap untuk diagnosis via `adb logcat` (tak diupload).
        debugPrint('firebase ai gagal: $e');
        final m = e.toString().toLowerCase();
        if (m.contains('app check') ||
            m.contains('appcheck') ||
            m.contains('app_check') ||
            m.contains('integrity')) {
          throw AiAppCheck(e.toString());
        }
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
