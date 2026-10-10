# SSR SPACE
**Simple. Secure. Reliable. Your Finance Space.**

Aplikasi Android pencatatan pengeluaran & pemasukan — multi-dompet, workspace Supabase, auto-track notif bank.

## Sesi awal enterprise
Splash → Onboarding (sekali) → PIN Lock → Home. Auto-lock 5 menit. Lockout 60 dtk setelah 5x salah.

## Auto-track notif
Lainnya → Pelacakan otomatis: izin notification listener, master switch, mapping dompet/kategori per app.
Allowlist package prefix (bukan substring). Dedup hash per hari. Tanggal = waktu terima notif.

## Migrasi Supabase (wajib)
Jalankan berurutan di SQL Editor bila belum:
`schema.sql` → `migration_squashed.sql` (baseline gabungan 02..19, Batch 7;
DB lama yang sudah termigrasi tak perlu apa-apa)
(daftar lengkap & urutan: AGENTS.md §3.4)

- baseline squash: isi = 07 (join+mint guard) + 08 (anti-recursion) + 12 (fix bikin workspace) + 13 (retention pg_cron) + 14 (admin) + 15 (We Space) + 16 (budget alerts) + 17 (kuota server-side) + 18 (month_mix + heartbeat) + 19 (realtime) + fondasi awal

## CI (3 workflow)
- `build-apk` — analyze + test + APK release (action di-pin SHA, dependabot weekly)
- `rls-test` — suite test RLS server-side (`supabase/test/`) tiap perubahan `supabase/**`
- `backup-db` — pg_dump mingguan (butuh secret `SUPABASE_DB_URL`)

## Build via gh
```bash
gh repo create SSR-SPACE --private --source=. --push
gh run watch
gh run download -n ssr-space-apk
```
