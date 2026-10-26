# SSR SPACE

**Simple. Secure. Reliable. Your Finance Space.**

Aplikasi Android untuk mencatat pengeluaran & pemasukan — multi-dompet, workspace bersama (Supabase), dan pelacakan otomatis dari notifikasi bank. Dibangun dengan Flutter + Supabase.

---

## Fitur

- **Multi-dompet** — kelola beberapa dompet sekaligus (tunai, bank, e-wallet) dengan saldo terpisah.
- **Workspace bersama** — satu workspace bisa dipakai beberapa orang (We Space) dengan kontrol akses berbasis RLS.
- **Auto-track notifikasi bank** — transaksi tercatat otomatis dari notifikasi app bank/e-wallet lewat notification listener. Mapping dompet & kategori per app, allowlist package prefix (bukan substring), dedup per hari.
- **Keamanan lokal** — PIN lock, auto-lock 5 menit, lockout 60 detik setelah 5x salah.
- **Budget & alert** — pengingat anggaran per kategori.
- **Laporan** — ringkasan pemasukan/pengeluaran per periode, mix bulanan (`month_mix`).
- **Sinkronisasi realtime** — perubahan data tampil langsung antar anggota workspace.

---

## Alur sesi awal

```
Splash → Onboarding (sekali) → PIN Lock → Home
```

Auto-lock setelah 5 menit idle. Lockout 60 detik setelah 5 kali salah PIN.

---

## Auto-track notifikasi

Buka **Lainnya → Pelacakan otomatis**:

1. Beri izin **notification listener**.
2. Nyalakan **master switch**.
3. Set **mapping dompet & kategori** per aplikasi bank/e-wallet.

Catatan teknis:
- Allowlist memakai **package prefix**, bukan substring.
- Dedup memakai hash per hari.
- Tanggal transaksi = waktu notifikasi diterima.

---

## Setup Supabase (wajib untuk instalasi baru)

Jalankan berurutan di **SQL Editor** Supabase:

```
schema.sql → migration_squashed.sql
```

`migration_squashed.sql` adalah baseline gabungan migrasi 02..19 (Batch 7). Database lama yang sudah termigrasi **tidak perlu** menjalankan apa pun.

Daftar lengkap & urutan: lihat `AGENTS.md §3.4`.

Isi baseline squash:

| # | Isi |
|---|-----|
| 07 | Join + mint guard |
| 08 | Anti-recursion |
| 12 | Fix bikin workspace |
| 13 | Retention pg_cron |
| 14 | Admin |
| 15 | We Space |
| 16 | Budget alerts |
| 17 | Kuota server-side |
| 18 | month_mix + heartbeat |
| 19 | Realtime |
| — | Fondasi awal |

---

## Build & CI

### Workflow GitHub Actions

| Workflow | Trigger | Isi |
|----------|---------|-----|
| `build-apk` | push / PR | `flutter analyze` + test + build APK release (action di-pin SHA, dependabot weekly) |
| `rls-test` | perubahan `supabase/**` | Suite test RLS server-side (`supabase/test/`) |
| `backup-db` | mingguan | `pg_dump` (butuh secret `SUPABASE_DB_URL`) |

### Build lokal via `gh`

```bash
gh run watch
gh run download -n ssr-space-apk
```

> Repo sudah ada di `Sendysyah27/SSR-SPACE`. Untuk fork baru, buat repo dulu lalu push.

---

## Struktur repo

```
lib/              kode aplikasi Flutter (Dart)
android-native/   modul Android native (notification listener, dsb)
supabase/         skema SQL, migrasi, test RLS
test/             unit & widget test
assets/           ikon, font, gambar
docs/             dokumentasi teknis & panduan
```

---

## Dokumentasi

- `AGENTS.md` — aturan kerja & arsitektur lengkap
- `AUDIT.md` — hasil audit keamanan & kualitas
- `DESIGN.md` — panduan desain UI
- `HANDOFF.md` — catatan serah-terima antar sesi

---

## Lisensi

Belum ditentukan.
