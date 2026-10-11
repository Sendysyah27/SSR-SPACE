// Buka file hasil ekspor dari ketuk notifikasi. Murni Dart: parsing
// payload + tebak MIME dari ekstensi (pemanggil yang platform-specific).

/// Prefix payload notifikasi ekspor (lihat ExportSavedNotify).
const exportOpenPrefix = 'share_file:';

/// Path file dari payload ketuk badan notifikasi, null bila bukan
/// payload ekspor / kosong.
String? exportOpenPath(String? payload) {
  if (payload == null || !payload.startsWith(exportOpenPrefix)) return null;
  final path = payload.substring(exportOpenPrefix.length);
  return path.isEmpty ? null : path;
}

/// MIME eksplisit untuk ekstensi yang didukung, null = serahkan ke plugin.
String? exportOpenMime(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return null;
}
