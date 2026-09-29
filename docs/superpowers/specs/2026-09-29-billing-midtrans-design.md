# Spec: Billing Pro via Midtrans Snap (QRIS) — full-oto tanpa PC

Tanggal: 2026-09-29 · Versi dasar: 2.6.0+48 · Target rilis: 2.7.0+49
Status: PAUSED 2026-09-29 — nunggu server verifikasi dokumen Midtrans normal (KYC production). Sandbox siap kapan saja; S1+S2+S3 sudah disetujui. Revisi GoPay: Midtrans tetap, metode dibatasi gopay+qris, copy "Bayar pakai GoPay" (hasil spike: reverse GoPay merchant DITOLAK — repo hilang, tool berbayar, risiko banned).

Keputusan user yang mengunci (sesi brainstorm 2026-09-29):
1. Harga Pro = Rp15.000/bulan per workspace (turun dari Rp25.000).
2. Belum punya akun Midtrans → daftar sandbox dari browser HP.
3. HP saja (tanpa PC) → deploy edge function via GitHub Action.
4. Pendekatan B full-oto Midtrans (bukan manual transfer, bukan link manual).

Aturan repo yang berlaku: migration baru `migration_16_billing.sql` (user jalankan manual setelah migration_15); secrets TIDAK masuk repo (GitHub Secrets + Supabase Function secrets via Dashboard); satu dep baru `url_launcher` (buka Snap di browser); bump Skema A + changelog; 1 commit fitur + CI hijau + APK arm64; catat AGENTS/AUDIT.

Non-tujuan (sengaja di luar scope): QRIS production sungguhan (butuh KYC/aktivasi Midtrans, user lakukan sendiri nanti); langganan otomatis/recurring (v1 = bayar manual tiap 30 hari); refund/chargeback handling; multi-mata-uang.

---

## S1. Alur bayar (server + DB)

1. `supabase/functions/create-snap/index.ts` (perbaiki, deploy ulang):
   - Input: `{ orgId }` (amount TIDAK dari client — server tetapkan 15000, anti-tamper).
   - Buat `order_id = 'ssr-<orgId8>-<epoch>'` (unik per order, traceable).
   - Panggil Snap API (base ikut `MIDTRANS_IS_PRODUCTION`): `transaction_details { order_id, gross_amount: 15000 }`, tanpa `enable_payments` (semua metode aktif Midtrans tampil termasuk QRIS/GoPay/VA).
   - Simpan `subscriptions(org_id, plan='pro', status='pending', amount=15000, snap_token, order_id)` — butuh kolom baru `order_id text` (lihat migration).
   - Return `{ token, redirect_url }`. Auth: `--no-verify-jwt` + cek manual? TIDAK — pakai verify-jwt default (panggil dengan user JWT dari client, ambil `auth.uid()` untuk validasi membership org sebelum buat order).
2. `supabase/functions/midtrans-webhook/index.ts` (baru):
   - Terima POST JSON Midtrans; verifikasi signature: `SHA512(order_id + status_code + gross_amount + serverKey)` == `signature_key`, tolak bila beda.
   - `transaction_status == 'settlement'` (atau `capture`+`fraud accept`) → dengan service_role: `subscriptions set status='settled', paid_at=now() where order_id` + `organizations set plan='pro' where id`.
   - Status lain (`pending`/`deny`/`expire`/`cancel`) → update status subscriptions saja, plan tidak berubah.
   - Idempoten: `settlement` kedua untuk order sama = no-op (cek status dulu).
3. `supabase/migration_16_billing.sql` (idempoten): `subscriptions add column if not exists order_id text unique, paid_at timestamptz`.
4. `billing_service.dart`: `proPrice 25000 → 15000`; `currentPlan(orgId)` dibaca sebagai: latest `subscriptions` settled dengan `paid_at > now()-30hari` ADA → `'pro'`, selain itu ikut `organizations.plan` fallback `'free'`? JUJUR: sumber kebenaran = subscriptions (bayar menentukan), `organizations.plan` dipertahankan untuk kompatibel (ditulis webhook juga). Bila tak ada settled ≤30 hari → `'free'` walau kolom plan masih 'pro' (grace: tidak ada, habis = habis — sampaikan di UI "Pro sampai {tanggal}").
5. RLS: `subscriptions` policy lama (member all) cukup untuk baca; INSERT order via edge fn (service_role) bukan client — client TIDAK insert langsung lagi (`requestUpgrade` dihapus dari flow bayar, atau dipertahankan? HAPUS pemakaian, fungsi tetap untuk kompatibilitas? Hapus total bila nol rujukan lain).

## S2. Deploy tanpa PC + secrets

1. `.github/workflows/deploy-functions.yml` (baru): trigger push `supabase/functions/**` + manual dispatch; steps: checkout → `supabase/setup-cli` (pin versi) → `supabase link --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}` → `supabase functions deploy create-snap --no-verify-jwt`? KEPUTUSAN: create-snap pakai verify-jwt (lihat S1) → deploy TANPA flag; webhook HARUS `--no-verify-jwt` (Midtrans tak punya JWT) + verifikasi signature di dalam function. Secrets GitHub baru: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` (user tempel dari Dashboard).
2. Secrets Supabase (Dashboard → Edge Functions → Secrets, via browser HP): `MIDTRANS_SERVER_KEY` (dari dashboard Midtrans sandbox), `MIDTRANS_IS_PRODUCTION=false`. Service role key otomatis tersedia di edge env (jangan set manual).
3. Daftar Midtrans sandbox (user, dari HP): midtrans.com → sign up → Sandbox → dapat Server Key + Client Key (client key tak dipakai v1) → Settings → Payment Notification URL = `https://<ref>.supabase.co/functions/v1/midtrans-webhook` (diisi SETELAH deploy pertama).

## S3. Client + uji + rilis

1. Dep baru: `url_launcher: ^6.x` (pin minor saat implementasi, cek versi terbaru yang kompatibel stable) — buka `redirect_url` Snap di browser eksternal (mode `externalApplication`, user bayar QRIS dari HP yang sama: screenshot/scan silang atau GoPay di HP sama).
2. `BillingScreen`: ganti `_upgrade` (insert pending) → `_pay`: panggil edge fn (user JWT otomatis via supabase_flutter `invoke`) → `launchUrl(redirect)` → tampil tombol "Cek status" (panggil `currentPlan`, refresh bila settled). `initState`+`resume` (route pop / app resume via `didChangeAppLifecycleState`? SEDERHANA: cek di `_load` + tombol manual saja — tanpa lifecycle observer, jujur secukupnya).
3. Copy baru ID+EN (`bl_*`): `bl_pay` (Bayar Rp15.000), `bl_check` (Cek status), `bl_pro_until` (Pro sampai {tgl}), `bl_qris_hint` (Pilih QRIS/GoPay/VA di halaman bayar).
4. Uji jujur v1 (sandbox): buat order dari app → Snap terbuka → bayar via simulator Midtrans (dashboard sandbox) → webhook → plan flip pro → tombol Cek status hijau. Bukti = screenshot + CI hijau. QRIS scan dompet asli = production, di luar v1.
5. Rilis: bump `2.7.0+49` + changelog + CI + APK arm64. Instruksi user: (a) jalankan migration_16, (b) daftar sandbox + tempel secrets, (c) isi notification URL setelah deploy.

---

## Self-review spec (2026-09-29)

1. Placeholder: tidak ada TBD — harga, nama file/fungsi/kolom, URL pola, dan langkah user konkret.
2. Konsistensi: amount hanya dari server (anti-tamper) ↔ client tak kirim amount; webhook service_role ↔ tanpa policy baru; expiry via paid_at ↔ tanpa cron; `--no-verify-jwt` hanya webhook + signature check (create-snap tetap verify).
3. Scope: satu plan (2 edge fn + 1 migration + 1 workflow + billing screen + 1 dep). Recurring/refund/production-KYC eksplisit non-tujuan.
4. Ambiguitas: `order_id` format pasti; `currentPlan` definisi pasti (settled ≤30 hari); sumber kebenaran ganda (subscriptions + organizations.plan) dijelaskan — webhook tulis keduanya agar baca lama tetap benar.
