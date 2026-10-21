import 'package:ssr_space/services/app_config_service.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/utils/org_prefs.dart';

// Badge entry AI Scan (batch 284 tahap D, pola badge Ollo): sisa
// kuota AI dari check_quota server (angka) + label promo dari
// app_config kunci 'ai_promo' (seed migration_29). Semua fail-open:
// gagal / data asing -> badge null (tidak tampil), tak pernah blokir.

/// Label badge kuota dari hasil check_quota mentah. Murni.
/// Pro -> 'PRO'; Gratis -> sisa (limit - used, min 0); asing -> null.
String? aiQuotaBadgeLabel(Map<String, dynamic>? q) {
  if (q == null) return null;
  final plan = (q['plan'] ?? '').toString();
  if (plan == 'pro') return 'PRO';
  final used = (q['used'] as num?)?.toInt();
  final limit = (q['limit'] as num?)?.toInt();
  if (used == null || limit == null || limit <= 0) return null;
  final left = limit - used;
  return '${left < 0 ? 0 : left}';
}

/// Label badge promo dari nilai app_config 'ai_promo' mentah. Murni.
/// Kosong -> null; nilai dipangkas maks 16 char.
String? aiPromoBadgeLabel(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  return v.length <= 16 ? v : v.substring(0, 16);
}

/// Muat kedua badge untuk entry "Record with AI" (kartu scan).
/// Fail-open penuh per badge.
Future<({String? quota, String? promo})> loadAiEntryBadges() async {
  String? quota;
  String? promo;
  try {
    final orgId = await activeOrgId();
    if (orgId.isNotEmpty) {
      quota = aiQuotaBadgeLabel(await quotaCheck(orgId, 'ai'));
    }
  } catch (_) {}
  try {
    final svc = AppConfigService();
    await svc.refresh();
    promo = aiPromoBadgeLabel(svc.getString('ai_promo'));
  } catch (_) {}
  return (quota: quota, promo: promo);
}
