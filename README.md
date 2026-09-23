# SSR SPACE
Aplikasi Android pencatatan pengeluaran & pemasukan — offline, multi-dompet.

## Sesi awal enterprise
Splash → Onboarding (sekali) → PIN Lock → Home. Auto-lock 5 menit. Lockout 60 dtk setelah 5x salah.

## Build via gh
```bash
gh repo create SSR-SPACE --private --source=. --push
gh run watch
gh run download -n ssr-space-apk
```
