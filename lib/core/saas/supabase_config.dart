import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static String get safeUrl => url.trim().replaceAll(RegExp(r'/+$'), '');
  static String get safeKey => anonKey.trim();
  static bool get isConfigured => safeUrl.isNotEmpty && safeKey.isNotEmpty;

  static String get host {
    try {
      return Uri.parse(safeUrl).host;
    } catch (_) {
      return safeUrl;
    }
  }

  static Future<void> init() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: safeUrl, anonKey: safeKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
