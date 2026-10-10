# SPRINT LAPORAN — 4 Hari, Batch 1–3 (QA Final, tanpa push)

Tanggal: 2026-10-10 · Pohon: `b2f9868` · Versi: `2.16.0+87` · Status: QA lulus, siap push saat user bilang gas.

## Ringkasan batch

| Batch | Isi | Commit | CI |
|---|---|---|---|
| 1 | Lupa password via deep-link + guard invite fail-closed | `f4c19f8` (`2.14.0+85`) | build-apk success |
| 2 | Wizard auto-track 3 langkah + pagination Transaksi | `fb5050b` (`2.15.0+86`) | build-apk success |
| 3 | Kuota server-side + billing jujur (Hibrida) | `13c764f` + fix import `b2f9868` (`2.16.0+87`) | rls-test + build-apk success |

### Batch 1 — akses pulih
- `AuthService.resetPassword/updatePassword`; `PinLinkVerify.consume` terima
  `type=recovery` → flag `passwordRecovery`; `SetPasswordScreen` baru;
  routing Splash (initial-link anti-race) + AuthScreen/MainShell (hangat).
- Invite: `tryParseInviteDate` fail-closed (rusak → kedaluwarsa, label `–`).
- Tanpa migration/dep/config Dashboard baru (pakai ulang callback PIN).

### Batch 2 — adopsi + skala baca
- `TrackWizardScreen`: izin → master → mapping (pakai ulang `BankTrackRow`),
  flag `track_wizard_done`; tombol + banner dismissable di notif_settings.
- Transaksi: `listMonthPage` (`.range`, halaman 100) + `txPageHasMore` murni,
  infinite scroll + footer + caption jujur `tx_partial`; `listMonth` lama utuh.

### Batch 3 — kuota jujur (keputusan: Hibrida)
- `migration_17_quotas.sql`: RPC `check_quota` + trigger `trg_auto/member/workspace_quota`
  → `QUOTA_EXCEEDED` (Gratis: ws 2, anggota 3, auto 150/bln; Pro bebas).
- Klien server-dulu-lokal-fallback; error jujur (`saveErrorStatus`, `iv_quota`);
  Billing: tombol palsu → chip `bl_soon`, tanpa baris pending.
- **User wajib jalankan `migration_17` manual** (setelah 16).

## File yang diubah/baru
- Baru: `set_password_screen.dart`, `password_reset_logic.dart`, `track_wizard_screen.dart`,
  `migration_17_quotas.sql`, `docs/SPRINT_{AUDIT,ROADMAP}.md`, test `password_reset`, `tx_pagination`.
- Ubah: `auth_service`, `pin_link_verify`, `splash/auth/main_shell`, `invite_token`,
  `invite_screen`, `transaction_service`, `transactions_screen`, `notif_settings`,
  `notif_track_service`, `plan_limits`, `org_switcher`, `billing_screen`, `strings`
  (+37 kunci ID/EN), `pubspec` + `app_info` + `changelog` + `AGENTS/AUDIT/README`.

## Bukti QA (fresh, perintah di pesan ini)
- RLS suite lokal: **68 asserts, SUKSES, 0 ERROR** (termasuk T28–T30).
- Logika murni standalone (`dart --enable-asserts`): **7/7 LULUS**.
- Konsistensi: versi triple `2.16.0+87` cocok; 37 kunci baru terdefinisi +
  terpakai (2 temuan skrip = false positive ternary, terkonfirmasi manual);
  16 file migration; docs urutan migration sinkron (AGENTS/README).
- Integrasi: wiring recovery 3 titik + gate server 3 titik + changelog 3 seksi
  terkonfirmasi; CI hijau di pohon final (build-apk `b2f9868`, rls `13c764f`).

## Yang TIDAK terverifikasi (jujur)
- `flutter test`/`analyze` lokal: tak ada Flutter di Termux — bukti dari CI.
- Device: alur lupa-password end-to-end, wizard izin→kembali, bulan >100 tx,
  kuota mentok (151/ke-4/ke-3) setelah migration_17.
- `migration_17` belum dijalankan di Supabase produksi (aksi user).

## Sisa tech debt (di luar sprint)
1. `requestUpgrade` + key `bl_cta` yatim (untuk Midtrans penuh nanti).
2. `dashboard_service` yatim; dep mati `flutter_secure_storage`/`local_auth`.
3. Tanpa DB lokal + `listMonth` 200 di beranda/laporan (Batch 3 roadmap).
4. Migration manual 17 file; free-tier pause 7 hari (D8); wizard widget refresh
   native masih disable; tanpa reset... (selesai Batch 1) — sisa: OAuth, realtime.
