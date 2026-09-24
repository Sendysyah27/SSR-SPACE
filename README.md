# SSR SPACE
Aplikasi Android pencatatan pengeluaran & pemasukan — multi-dompet, workspace Supabase, auto-track notif bank.

## Sesi awal enterprise
Splash → Onboarding (sekali) → PIN Lock → Home. Auto-lock 5 menit. Lockout 60 dtk setelah 5x salah.

## Auto-track notif
Lainnya → Pelacakan otomatis: izin notification listener, master switch, mapping dompet/kategori per app.
Allowlist package prefix (bukan substring). Dedup hash per hari. Tanggal = waktu terima notif.

## Migrasi Supabase (wajib)
Jalankan berurutan di SQL Editor bila belum:
`schema.sql` → `migration_02` … `migration_07_security.sql`
(migration 07: join workspace hanya pembuat/owner-admin + `mint_tx_code` wajib member)

## Build via gh
```bash
gh repo create SSR-SPACE --private --source=. --push
gh run watch
gh run download -n ssr-space-apk
```
