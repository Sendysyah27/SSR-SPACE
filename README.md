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
`schema.sql` → `migration_02` … `migration_19_realtime.sql`
(daftar lengkap & urutan: AGENTS.md §3.4)

- migration 07: join workspace hanya pembuat/owner-admin + `mint_tx_code` wajib member
- migration 08: **wajib jika sudah jalan 07** — hapus policy SELECT org_members yang bikin RLS recursion ("Gagal memuat dompet")
- migration 12: **fix P0 bikin workspace baru gagal** sejak 07 + re-join invite idempoten
- migration 13: retention pg_cron harian (client_errors 30h, audit_logs 180h)
- migration 14: admin workspace (kick, hapus + RPC)
- migration 15: We Space (mode Bebas/Bendahara + RPC + trigger tulis)
- migration 16: peringatan budget real-time (trigger + tabel budget_alerts)
- migration 17: **kuota paket server-side** (RPC check_quota + 3 trigger QUOTA_EXCEEDED; Pro = `organizations.plan`)
- migration 18: **skala baca + heartbeat** (RPC month_mix + tabel heartbeat/touch + cron harian guarded)
- migration 19: **realtime sync** (REPLICA IDENTITY FULL + publication guarded; channel per org di app)

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
