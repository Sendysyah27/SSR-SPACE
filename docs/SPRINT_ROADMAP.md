# SPRINT ROADMAP — 4 Hari (dari `docs/SPRINT_AUDIT.md`)

Prinsip: ikut urutan rekomendasi audit §4.5. Tiap batch = 1 push, CI hijau, APK arm64.
Aturan repo tetap: bump version + changelog tiap push kode; docs ikut push yang sama.

## Batch 1 — Hari 1: Akses pulih (P0 murah)
- (1) Lupa password via `resetPasswordForEmail` + deep-link `recovery` (pakai ulang
  skema `pinLinkCallback`, nol config Dashboard baru) → layar password baru → `updateUser`.
- (2) Guard `DateTime.tryParse` di `invite_screen` (status fail-closed kedaluwarsa,
  label tanggal fallback `–`).
- Estimasi: 1 push. File: `auth_service`, `auth_screen`, `pin_link_verify`
  (terima type `recovery`), layar password baru kecil, `strings`, invite + test.
- Done bila: CI hijau + APK + link recovery device → password baru → login.

## Batch 2 — Hari 2: Kuota jujur + putusan billing (P0 bisnis)
- (a) Penegakan kuota server-side (RPC `can_auto_track` + cek invite/workspace —
  ganti gate client-only yang fail-open).
- (b) Putusan produk (butuh user): **cabut klaim Pro** (Billing jadi "segera hadir",
  murah) ATAU **sambung Midtrans penuh** (deploy `create-snap` + webhook + update
  `plan`, butuh aksi Dashboard/CLI user — bisa melar ke Hari 3).
- Estimasi: 1–2 push + migration baru (manual user). Rekomendasi default: (a) + cabut
  klaim bila Midtrans belum siap.

## Batch 3 — Hari 3: Data tahan banyak (P1 kapasitas)
- Pagination riwayat (ganti limit 100/200 keras) + infinite scroll di
  Transaksi/Laporan/Riwayat Dompet.
- Cache baca + kurangi reload Beranda (beban egress + 12-bulan query tiap resume).
- Cache `plan` per sesi (hapus N+1 per layar).
- Estimasi: 1–2 push, tanpa migration. Done bila: user 500+ tx/bulan tetap lengkap.

## Batch 4 — Hari 4: Adopsi + nyala terus (P1)
- Wizard auto-track 3 langkah (izin → master → peta dompet) di onboarding/pengaturan.
- Heartbeat anti-pause D8 (aktivitas DB harian, cegah pause 7 hari free-tier).
- Deep-link undangan (buka app + prefill kode) bila sempat; sisa = backlog.
- Estimasi: 1 push (+ cron/pg_net atau edge ringan untuk heartbeat).

## Backlog (di luar sprint)
Hapus `dashboard_service` yatim + dep mati (`flutter_secure_storage`, `local_auth`)
atau pakai; squash 15 migration + cek skema saat boot; realtime kolaborasi;
analitik adopsi; listing Play Store + kebijakan privasi.
