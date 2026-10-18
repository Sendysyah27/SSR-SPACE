/// Kontrak kode error trigger Postgres (fix #12).
///
/// Trigger DB melempar `raise exception '<KODE>'` TANPA errcode kustom,
/// sehingga `PostgrestException.code` selalu 'P0001' untuk semuanya dan
/// TIDAK bisa dipakai membedakan jenis error. Satu-satunya pembeda adalah
/// TEKS pesan.
///
/// => Teks-teks di bawah adalah KONTRAK dengan migration DB. Bila migration
/// diubah (teks diganti / errcode kustom ditambahkan), update HANYA file ini
/// lalu perkuat helper memakai `e.code`.
///
/// ATURAN: semua pemetaan error trigger WAJIB lewat helper di sini.
/// Dilarang `message.contains('QUOTA_EXCEEDED')` (atau sejenisnya) tersebar
/// di codebase — itu yang membuat mapping gagal diam-diam saat pesan berubah.
library;

/// Kuota paket mentok (trigger: migration_17 tx, migration_20 wallet/entitlement).
bool pgIsQuotaExceeded(Object e) => '$e'.contains('QUOTA_EXCEEDED');

/// Rate limit auto-insert notifikasi (trigger: migration_11).
bool pgIsRateLimited(Object e) => '$e'.contains('RATE_LIMITED');

/// Aksi butuh admin/owner (trigger/fungsi: NOT_ADMIN).
bool pgIsNotAdmin(Object e) => '$e'.contains('NOT_ADMIN');

/// Mode workspace tidak valid (fungsi set_space_mode: BAD_MODE).
bool pgIsBadMode(Object e) => '$e'.contains('BAD_MODE');

/// Tendang owner terakhir dilarang (fungsi kick: KICK_LAST_OWNER).
bool pgIsKickLastOwner(Object e) => '$e'.contains('KICK_LAST_OWNER');

/// RPC butuh login (fungsi invite: NOT_AUTHENTICATED).
bool pgIsNotAuthenticated(Object e) => '$e'.contains('NOT_AUTHENTICATED');
