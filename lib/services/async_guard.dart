/// Penjaga Future individual (Dart murni, tanpa flutter).
///
/// Tiap Future yang gagal WAJIB kembali sebagai fallback, bukan throw:
/// satu service lempar (jaringan putus, RLS, prefs korup, plugin) tak boleh
/// membunuh layar pemanggil. Dipakai Beranda + MainShell untuk semua
/// panggilan async yang sebelumnya tanpa pengaman individual.
Future<T> guardAsync<T>(Future<T> Function() fn, T fallback) async {
  try {
    return await fn();
  } catch (_) {
    return fallback;
  }
}

/// Varian void: jalankan, telan semua error (fire-and-forget aman).
Future<void> runGuarded(Future<void> Function() fn) async {
  try {
    await fn();
  } catch (_) {}
}
