import 'ai_cli_client.dart';

// Alias tipis jalur chat AI.
//
// Catatan audit P3-9 (2026-11-25): jalur Zen-direct LAMA DIHAPUS dari
// file ini — `parseReceiptZen`, `zenChatRaw`, `_zenPost`, `_readText`,
// `_readSnippet` + konstanta endpoint/model/fallback + sesi Zen
// (semua 0 pemanggil produksi; hanya test yang memakai). Zen tetap
// hidup lewat router `aiChatViaCli` (provider 'zen' -> MethodChannel
// native ZenProvider), jadi tak ada fitur yang hilang.
//
// `aiChat` dipertahankan sebagai delegasi agar pemanggil lama
// (ai_chat_screen, reports_screen) tak perlu diubah.
Future<({String text, String provider})> aiChat(
  String prompt, {
  List<int>? imageBytes,
  String? mimeType,
  List<({bool mine, String text})>? history,
  String? dataContext,
  // System prompt kustom. null = default.
  String? system,
}) {
  return aiChatViaCli(
    prompt,
    imageBytes: imageBytes,
    mimeType: mimeType,
    history: history,
    dataContext: dataContext,
    system: system,
  );
}
