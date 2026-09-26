# AGENTS.md — SSR SPACE

Panduan kerja untuk agent / contributor di repo ini. Baca dulu sebelum ubah kode.

---

## 1. Identitas projek

| | |
|---|---|
| Nama | **SSR SPACE** |
| Path | `/data/data/com.termux/files/home/SSR SPACE` |
| Remote | `https://github.com/Sendysyah27/SSR-SPACE.git` |
| Versi | `2.3.9+22` (`pubspec.yaml`) |
| Stack | Flutter (stable) + Supabase (Auth + Postgres RLS) + Notification Listener |
| Bahasa UI | Indonesia |
| Build | GitHub Actions (`.github/workflows/apk.yml`), **bukan** lokal Termux |
| APK hasil | artifact `ssr-space-apk` di run Actions terakhir |
| Package id | `com.ssr.space.ssr_space` (`ownPackage` di `notif_track_service.dart`) |

**Bukan lagi app offline sqflite penuh.** Storage utama = Supabase cloud per workspace. Spec lama di `docs/superpowers/specs/` sebagian basi — lihat bagian update di situ (ada catatan 2026-09-24).

---

## 2. Tujuan produk (goal)

**Tagline resmi (keputusan 2026-09-25):** ***Simple. Secure. Reliable. Your Finance Space.***
(Kata "Offline" dibuang dari tagline lama; storage tetap Supabase cloud. Posisi = ruang keuangan pribadi yang tenang, bukan klaim teknis offline.)

Aplikasi Android pencatatan keuangan harian untuk user Indonesia:

1. **Catat pemasukan & pengeluaran** multi-dompet (Kas, DANA, Bank, dll).
2. **Workspace (org)** multi-user: satu workspace = buku kas bersama / pribadi.
3. **Auto-track notifikasi bank & dompet digital** → jadi transaksi otomatis di workspace aktif (fitur pembeda utama).
4. Budget per kategori per bulan, laporan CSV/PDF, kode transaksi `TX-000001`.
5. Sesi aman: PIN + lockout, auto-lock 5 menit background.

---

## 3. Workflow yang SUDAH dilakukan (riwayat kerja)

Urutan penting — jangan diulang salah:

### 3.1 Fase awal (sebelum audit 2026-09-24)
1. Scaffold Flutter + session enterprise (PIN hash SHA-256+salt, lockout 5x→60s).
2. Desain `DESIGN.md`: palet kertas/zamrud, motif ledger, bottom nav 5 tab, dial ENERGY 1 / RHYTHM 2 / MOTION 1.
3. Migrate arsitektur dari “offline sqflite” → **Supabase SaaS** (auth, org, RLS).
4. Fitur inti: beranda surplus, transaksi, budget, laporan CSV/PDF, billing Midtrans edge fn.
5. Kode TX via RPC `mint_tx_code` + tabel `tx_sequences` (RLS deny direct).
6. **Auto-track notifikasi** bank/e-wallet → transaksi + badge “Otomatis”.
7. Tambah daftar bank: BRI, BNI, BTN, Jenius, Jago, Blu, CIMB, KEB Hana, ISAKU, dll.
8. CI: `flutter test` + `flutter build apk --release` + signing keystore dari GitHub Secrets.
9. Design pass: `DESIGN.md` + theme zamrud + `rp()` tabular + state standar.

### 3.2 Fase audit mendalam (2026-09-24) — fokus auto-track
Audit dilakukan dengan lensa **security-and-hardening** (threat model RLS + input notif).

Temuan utama yang dieksekusi:

| Prioritas | Temuan | Status |
|-----------|--------|--------|
| **P0** | RLS `join own org` hanya cek `user_id = auth.uid()` → user login manapun bisa auto-join org korban | ✅ fixed (`migration_07`) |
| **P0** | `mint_tx_code` SECURITY DEFINER tanpa cek membership → siapa pun bisa bakal sequence org lain | ✅ fixed |
| **P1** | Auto-track tanpa `wallet_id` → saldo multi-dompet tidak ikut | ✅ fixed (mapping pref + auto-match nama) |
| **P1** | `category` = nama app (`"DANA"`) → budget kacau | ✅ fixed (pref `track_cat_*`, default null) |
| **P1** | `date` selalu `current_date` server | ✅ fixed (kirim `ymd(waktu terima)`) |
| **P1** | Match package = substring bebas (`blu`, `dana`, `btn`) → false positive | ✅ fixed (allowlist prefix titik) |
| **P1** | Hash dedup permanen tanpa hari → notif identik beda hari ditolak | ✅ fixed (hash per hari) |
| **P1** | `mintCode` sebelum insert → nomor TX terbakar bila insert gagal | ✅ fixed (insert dulu, mint+update) |
| **P2** | WIP `createdAt` tanpa constructor → analyzer error | ✅ fixed |
| **P2** | Test hanya parse | ✅ ditambah `notif_track_test` |
| **P0 regression** | `migration_07` policy SELECT `org_members` self-ref → **RLS recursion** → “Gagal memuat dompet” | ✅ fixed (`migration_08`) |

### 3.2b Roadmap scale (disepakati 2026-09-24, sesi brainstorm)

Arah pengembangan ke **skala banyak user** — urutan wajib dijaga, jangan melompat:

| Fase | Isi | Status |
|------|-----|--------|
| **Fase 1** | **Fitur inti:** foreground service auto-track (`specialUse`) + invite workspace (token hash + RPC `join_org_by_invite`, `migration_10`) | ✅ done 2.3.6+19: kode selesai, CI milestone 2 hijau (run `36075349074`); catatan: `migration_10` masih dijalankan manual user, foreground service baru aktif setelah install APK baru |
| Fase 2 | Hardening: rate limit auto-insert (A3), audit log (A4), error monitoring, backup DB (D5), `flutter analyze` di CI (D1) | ✅ **done 2.3.7+20** (2026-09-25): D1 analyze CI (`739fbb4`+`e7e88e8`, run `36090886163`); A3+A4+monitoring+D5 (`74d85c5`…`105beaf`), CI run `36098447278` hijau penuh. Catatan: `migration_11_hardening.sql` masih dijalankan manual user |
| Fase 3 | Scale ops: cek limit plan Supabase, dependabot/pin actions SHA (D4), test RLS server-side | ✅ **done 2026-09-25**: limit plan ✅ (spike, rekomendasi AUDIT §4 — free cukup, **waspada pause 7 hari inaktif**, naik Pro $25/bln saat launch Fase 4); D4 dependabot + pin SHA ✅ (`.github/dependabot.yml` + 4 action di-SHA, D2 sekalian: checkout v7.0.1 / setup-java v6.0.1); **F3-c test RLS CI** ✅ (`rls-test.yml` + `supabase/test/`, 40+ assert — **nemukan 2 P0/penting → migration_12**); **F3-d retention + backup** ✅ (migration_13 pg_cron + `backup-db.yml` mingguan). Sisa backlog: D8 heartbeat anti-pause |
| Fase 4 | Monetisasi: billing Midtrans per plan + limit kuota | 🟡 jalan (2026-09-25): kuota locked (Gratis: workspace 2, anggota 3, auto 150/bln, CSV saja) + `plan_limits.dart` + template PDF premium (`report_pdf.dart`, run `36153839333` hijau, 62 test) + **tegak 4 titik** (`89080a1`, run `36155923567` hijau, 67 test, APK `kuota-gratis`). Sisa: bayar Midtrans (snap→webhook→upgrade) |

### 4.14 Diskusi baru: riwayat dompet, kelompok laporan, PIN budget, settings (2026-09-25/26)

- **F1 riwayat dompet** (`3e089b6`, run `36186962893` hijau): ketuk baris → `WalletDetailScreen` + `listByWallet`.
- **F2 kelompok laporan:** chip filter Semua/Masuk/Keluar/Transfer + `transfer_detect.dart` (out+in nominal sama, dompet beda, ≤10 mnt, suggest-only badge, tanpa merge) + test.
- **F3 edit budget:** ketuk kartu → dialog edit limit → popup PIN (`verifyPin`) → simpan.
- **F4 settings:** `SettingsScreen` (ID/EN, kurs API `open.er-api.com` + cache, font 0.85–1.3, ganti PIN via OTP email) + `strings.dart` (seluruh copy UI), `currency.dart` (`amt()` sadar kurs, input dikonversi balik ke IDR), `monthLabel`/`dayLabel` & status notif mengikuti bahasa. PDF ikut bahasa app, angka tetap IDR. Material bawaan (dialog sistem) ikut bahasa HP, bukan app — batas sadar.
- **Follow-up i18n (2026-09-26, `207f512`+`8127fcf`, run `36204732391` hijau, 79 test):** commit F4 (`43feacc`) pecah analyze — `tr()` di dalam `const` (SnackBar/Text/InputDecoration/items/segments di 8 file) → drop `const` induk, `const` tetap di argumen murni (EdgeInsets, DuoIcon); import `fl_chart` yang terbuang dikembalikan; `unused_import` foundation di `currency.dart` dibuang; `_historyTitle` (method state) → top-level `txHistoryTitle()` karena dipakai `_TxHistorySection` (StatelessWidget). **Pelajaran CI: `flutter analyze` fatal bahkan untuk info** (`prefer_const_constructors` 1 baris = run merah).
- **Fix `transfer_detect` (2026-09-26, `833cc49`, run sama hijau):** greedy out-terawal dulu mengklaim `in` bersama sebelum lirik yang lebih dekat (test T3 `o2` vs `o1` gagal: Expected `o2`, Actual `o1`) → kumpulkan semua kandidat lalu pasangkan dari **gap terkecil global** (`_Candidate`, `usedOut`+`usedIn`). Diverifikasi lokal via `dart` murni (4/4 PASS) sebelum commit — pola ini bisa dipakai lagi untuk logika murni lain.
- **Waktu detail TxRow (2026-09-26, `84bee1b`+`553e9fd`, run `36210627031` hijau, 83 test):** helper `txWhenLabel()` di `datetime.dart` ("26 Sep 2026 • 12:04", tanggal saja bila jam kosong, sembunyi bila tak ada data) + baris `bodySmall` secondary tabular di `TxRow` bawah chips → Transaksi, Laporan, Riwayat Dompet otomatis dapat. Test `datetime_test.dart` (4 assert, ISO dibangun dari `DateTime` lokal biar aman TZ runner). Diverifikasi lokal via `dart` + stub `tr()` (7/7 PASS).
- **Koreksi instan auto-track (2026-09-26, 3 commit + 1 fix, run `36217156334` hijau, 90 test):** (1) `0506288` kategori global — `app_categories.dart` (10 default, sanitize trim/dedupe/cap-20, prefs `app_categories`, notifier; load di `main`) + `CategoriesScreen` (tambah/hapus/simpan/reset) di kartu Data Lainnya; (2) `0766aac` `CategoryChips` (wrap StatusChip → isi controller, ikut notifier) di form transaksi + budget; (3) `766c063` overlay 30 detik (`flutter_overlay_window` 0.5.0, entry `overlayMain`, shareData JSON, auto-tutup; Manifest+izin diinject CI) + sematan teks notif foreground 3 menit (`pinNotice`/`clearNotice`, ketuk → buka app) + sheet koreksi (chip kategori + catatan + Simpan/Lewati → `update()`, pending `pending_correct_tx` di prefs, dibuka MainShell saat resume/foreground) + toggle & izin overlay di notif_settings; fix `5f0c9a8` (import ganda, LabeledSectionCard). Tanpa `flutter_local_notifications` (pakai notif service yang ada — hindari desugar/AGP). Batas sadar: overlay tak di lockscreen (verifikasi di device); sheet tak dibuka bila app background (tunggu resume).
- **Peringatan tanpa-dompet (2026-09-26, opsi C lanjutan audit allowlist `ff8d84d`):** akar selisih Home vs Dompet = (1) beda metrik (surplus sebulan vs total aset sepanjang waktu), (2) `transfer` diabaikan Home tapi dihitung Wallet, (3) transaksi null-wallet masuk Home tapi tak masuk `wallet_balance`. Form manual ternyata **sudah wajib dompet** (`tx_validation.dart:10`) → kerja sisa: `tx_wallet_check.dart` (`hasNoWallet`/`noWalletTotal`) + test (5 assert, lokal `dart` 10/10); chip danger di `TxRow`; banner + filter di riwayat Transaksi; guard `_onEvent` tahan insert bila wallet null (`st_need_wallet`, Simpan manual tetap bisa).
- **SeaBank + Tes overlay (2026-09-26):** transfer SeaBank→BCA Rp17.000 — BCA tercatat (Income), SeaBank "unreadable". Allowlist benar; akar = classifier tak kenal "melakukan transfer … senilai Rp…" → out-key baru + test teks asli (regresi 7/7 lokal). Overlay tak muncul padahal toggle+izin ON → tersangka forceSave-tanpa-offer atau blokir MIUI; diagnosis = tombol Tes overlay di kartu Koreksi instan.
- **BigText fallback (2026-09-26, akar SeaBank "unreadable"):** plugin hanya baca `EXTRA_TEXT`, SeaBank taruh isi di BigText → `pubspec` pin `1.0.0` + patch Java via step `apk.yml` (assert keras). Verifikasi akhir di device.
- **Optimasi CI (2026-09-26):** build 9–10 → 12+ mnt karena tanpa cache (build apk 10m21s/85%). Pasang cache Flutter+pub+Gradle (pin SHA) + `paths-ignore` docs. Hemat terasa dari run kedua.
- **Auto-gabung transfer (2026-09-26, minta user):** pasangan out+in auto+auto (nominal sama, dompet beda, ≤10 mnt) langsung jadi 1 baris `transfer` — `pickAutoMerge()` + `_tryAutoMerge()` fail-open di `_onEvent` (histori lama tak diubah; kode TX milik OUT). `summary()` kenal transfer.
- **Ganti PIN magic-link (2026-09-26):** template email terkunci (perlu SMTP) → OTP 6 digit buntu → ganti PIN via deep-link: kirim link → ketuk → tukar token jadi sesi (`pin_link_verify.dart`, `app_links`, intent-filter CI). User wajib tambah redirect `com.ssr.space.ssrspace://login-callback` di Dashboard → Auth → URL Configuration.
- **Workspace premium (2026-09-26, SDD subagent):** detail workspace (anggota ID+peran, kick, hapus + ketik-nama + PIN) via RPC `migration_14` (wajib user jalankan) + assert T12-T15. Spec `docs/superpowers/specs/2026-09-26-workspace-premium-design.md`, plan `docs/superpowers/plans/2026-09-26-workspace-premium.md`.
- **Input transaksi premium (2026-09-26, `686316b`+`cfb0d54`, run `36251716559` hijau, 123 test):** tab Transaksi = riwayat saja (strip ringkasan Masuk/Keluar/Surplus-Defisit, rumus = beranda, transfer diabaikan); input pindah ke `TxInputSheet` via tombol **+ tengah `centerFloat`** (semua tab) / aksi + AppBar / ketuk baris (edit + hapus). Numpad custom 1-9/000/0/hapus (tanpa keyboard sistem, sadar desimal kurs, minor-eksak). Tanggal wajib default hari ini + jam opsional → kolom `date` + `created_at` custom (param `createdAt` baru di payload/add/update, **tanpa migration**). Logika murni `tx_input_logic.dart` (lokal `dart` 30/30) + `test/tx_input_test.dart` (21 case). Eksekusi pakai 3 subagents paralel (shell / test / review); review menemukan `localeCode` tak ke-import + `unused theme` sebelum push; CI sempat merah 1x (`)` kurang di numpad + `dangling_library_doc_comments` info). Batas sadar: `onCatat` Beranda masih navigasi ke tab (bukan buka sheet langsung).
- **Tabungan premium (2026-09-26, `5af4d82`+`2b2e920`, run `36254042802` hijau, 127 test):** konvensi kategori Tabungan/Savings **tanpa migration** (`saving.dart` murni: `isSavingCategory`/`savingOutOf`/`inOfMonth`, lokal `dart` 14/14 + `test/saving_test.dart`). Budget: kartu target emas (`SsrColors.saving` `#B45309` + soft, ilustrasi `savings.svg` dari Assets polish, chip `Tercapai` bila ≥100%) + banner bila total limit > pemasukan (hanya bila ada pemasukan) + hapus budget via PIN. Laporan: donut 3 iris (masuk/belanja/tabungan, legenda 3 kolom). Dompet: strip emas rincian + filter hanya-tabungan. Eksekusi: fondasi sendiri + 2 subagents layar paralel + review read-only (temukan `clamp→num` + 3 `prefer_const` + `hasSaving` dead → fix; lalu `const_with_non_const` karena `BorderRadius.circular` bukan const → revert). Batas sadar: banner limit mencakup target tabungan; legenda 3 kolom bisa sempit di 360dp (follow-up bila mengganggu).

Keputusan produk Fase 1: **foreground service penuh** (bukan opt-in), start dari `track_master`; parser/gate `_onEvent` TIDAK berubah.

### 3.3 Workflow teknis wajib setiap perubahan
```
1. Analisa / baca file terkait
2. Ubah kode + test (TDD kalau logika murni: parse, hash, gate)
3. git add → commit message jelas → push origin main
4. pantau: gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status
5. bila hijau: gh run download <run-id> -n ssr-space-apk
6. file final → /sdcard/Download/SSR-SPACE/ (rapi, nama jelas)
7. bila ubah SQL: JELASKAN migration apa yang harus user jalankan di Supabase
8. **SELESAI → catat hasil kerja di AGENTS.md (status/fitur) + AUDIT.md (changelog §7) secara LOKAL saja** — jangan commit docs sendirian (hemat 1 run CI); commit docs ikut digabung ke update berikutnya
```

**Jangan commit tanpa diminta user** (peraturan global HP ini), kecuali user sudah bilang “commit” / “lanjut push”.

**Aturan docs (2026-09-25, diubah 2026-09-26):** setiap pekerjaan selesai (fix, fitur, redesign, migration) **wajib dicatat lokal** di `AGENTS.md` + `AUDIT.md` — minimal changelog commit di AUDIT.md §7 dan baris status terkait di AGENTS.md. **Jangan commit docs sendirian** (satu commit docs = satu run CI full yang sia-sia); commit + push docs **digabung ke update berikutnya**, begitu seterusnya. Doc lokal boleh tertinggal ≤1 sesi dari push, jangan lebih.

### 3.4 Workflow Supabase migration
Semua SQL di `supabase/`. User jalankan manual di **Dashboard → SQL Editor**.

Urutan install fresh:
```
schema.sql
migration_02_org_policies.sql
migration_03_budgets.sql
migration_04_subscriptions.sql
migration_05_tx_codes.sql
migration_06_notif_source.sql
migration_07_security.sql
migration_08_fix_rls_recursion.sql   ← wajib bila pernah jalan 07 versi lama
migration_09_wallet_balance.sql
migration_10_org_invites.sql         ← Fase 1 (invite workspace)
migration_11_hardening.sql           ← Fase 2 (rate limit + audit_logs + client_errors)
migration_12_join_fixes.sql          ← fix P0 bikin workspace gagal + invite idempoten (2026-09-25)
migration_13_retention.sql           ← Fase 3 (pg_cron retention; di test suite dilewati, butuh pg_cron)
```

**Aturan RLS (jangan dilanggar):**
- Policy SELECT di `org_members` **TIDAK BOLEH** subquery ke `org_members` lagi → infinite recursion.
- Cek owner/admin pakai helper `public.is_org_admin(org_id)` (SECURITY DEFINER).
- Semua akses data org lewat `exists (select from org_members where org_id=... and user_id=auth.uid())` di tabel tsb.
- Policy di **`org_invites`** juga wajib lewat `is_org_admin` saja — jangan subquery `org_members`.
- Join workspace lain **HANYA** lewat RPC `join_org_by_invite`; jangan bikin jalur insert `org_members` baru selain `join own org` (created_by) dan RPC itu.
- `org_invites` menyimpan **hash sha256 token** saja, tidak pernah token asli.

---

## 4. Fitur yang telah update (detail per 2026-09-25, v2.3.7+20)

### 4.1 Sesi & auth
- Splash → **intro + persetujuan (user baru / belum setuju)** → Auth email/password Supabase → pilih/buat workspace → `MainShell`.
- **IntroConsentScreen** (`lib/screens/auth/intro_consent_screen.dart`): PageView 4 halaman (brand tagline → 3 nilai fitur → kesadaran finansial → syarat & persetujuan + checkbox). Centang wajib sebelum "Setuju & mulai". Disimpan di prefs `consent_v1` (timestamp ISO); gate ada di `SplashScreen._boot` **sebelum** cek workspace. User lama juga lihat sekali (flag belum pernah ada). Gagal tulis prefs → snackbar, tetap di layar.
- PIN: hash SHA-256 + salt 16 byte di storage; 5 salah → lockout 60 detik; auto-lock 5 menit.
- Verifikasi email wajib (resend tersedia).

### 4.2 Workspace (org)
- Buat: insert `organizations` dengan **`created_by = auth.uid()`** + insert self sebagai `owner` di `org_members`.
- RLS create org: `with check (created_by = auth.uid())`.
- RLS join: self hanya bila `created_by = auth.uid()`, ATAU `is_org_admin(org_id)` (owner/admin).
- Active org disimpan di prefs: `active_org_id`, `active_org_name`.
- Switch workspace di Lainnya → Ganti workspace.

### 4.3 Dompet
- CRUD sederhana (nama + type: cash/ewallet/bank).
- RLS: member org saja yang bisa baca/tulis.
- **Belum ada saldo terhitung otomatis** dari mutasi (lihat backlog).

### 4.4 Transaksi
- Tipe: `in` | `out` | `transfer` (transfer = 2 leg via `wallet_id` + `to_wallet_id`).
- Kode TX: di-insert **tanpa code dulu**, lalu `mint_tx_code` + UPDATE — gagal insert tidak bakal nomor.
- Urutan list: `date` DESC, `created_at` DESC.
- Badge “Otomatis” bila `source_package != null`.

### 4.5 Auto-track notifikasi (fitur inti)

**Pipeline:**
```
Android NotificationListener
  → NotifTrack.ensureListening()  (dipanggil di MainShell.initState)
  → _onEvent(ServiceNotificationEvent)
  → filter berurutan:
       1. bukan app sendiri
       2. package cocok allowlist (prefix)
       3. track_master == true
       4. track_<Label> != false
       5. session Supabase aktif
       6. active_org_id terisi
       7. amount > 0 dan type in/out terbaca
  → resolve wallet_id (pref track_wallet_<Label> atau auto-cocok nama)
  → kategori dari track_cat_<Label> (opsional, default null)
  → TransactionService.add(date: ymd(at), sourcePackage, sourceHash)
  → status di NotifTrack.recent (max 20, RAM saja)
```

**Allowlist package** (`lib/services/notif_parse.dart`) — match `package == prefix` atau `startsWith(prefix + '.')`:

| Label | Prefix package |
|-------|----------------|
| myBCA | `com.bca.mybca` |
| BCA | `com.bankcentralasia`, `com.bca.main`, `com.bca` |
| Livin Mandiri | `com.mandiri.mobile`, `com.bankmandiri` |
| DANA | `id.dana` |
| OVO | `com.vnoo.ovo`, `com.ovo`, `ovo.id` |
| GoPay | `com.gojek.app`, `com.gojek.gojek`, `com.gojek.gopay` |
| ShopeePay | `com.shopee`, `com.shopeepay` |
| SeaBank | `com.seabank`, `id.co.seabank`, `id.co.bankbkemobile`, `id.co.bankbke` |
| BRI | `com.bri.brimo`, `id.co.bri.brimo`, `com.bri.browser` |
| BNI | `com.bni`, `id.co.bni`, `src.com.bni` |
| BTN | `com.btn`, `id.co.btn` |
| Jenius | `com.btpn`, `id.co.btpn` |
| Jago | `id.co.jago`, `com.bankjago`, `com.jago.digitalBanking` |
| Blu | `com.bca.digital`, `id.co.bca.blu`, `com.bcadigital.blu` |
| CIMB | `com.cimb`, `com.octo`, `id.co.cimbniaga` |
| KEB Hana | `id.co.kebhana`, `co.id.myhana.app` |
| ISAKU | `com.isaku` |

Urutan list penting: **myBCA sebelum BCA**.

> **Catatan package (2026-09-25, A0):** SeaBank di Play Store memakai package lama BKE → **`id.co.bankbkemobile.digitalbank`** (bukan KEB Hana). KEB Hana asli = **`co.id.myhana.app`** (MyHana). Selalu verifikasi package asli dari Play Store / App info device sebelum menambah prefix.

**Parser:**
- Nominal: regex `Rp` pertama; `1.234.567` → 1234567; `10.800,00` → 10800.
- Klasifikasi: keyword in / out; bila **dua-duanya** ada → `null` (tidak dicatat, user bisa Simpan manual).
- Hash dedup: `sha256(YYYY-MM-DD | package | title | content)` — unik per org (index `unique_tx_hash`).

**Prefs keys:**
| Key | Arti |
|-----|------|
| `track_master` | master on/off (default **false**) |
| `track_<Label>` | toggle per app (default true) |
| `track_wallet_<Label>` | wallet id tujuan |
| `track_cat_<Label>` | kategori belanja (opsional) |
| `active_org_id` / `active_org_name` | workspace aktif |

**UI:** Lainnya → Pelacakan otomatis  
- Izin notification listener  
- Master switch  
- Per app: toggle + dropdown dompet + field kategori  
- “Pindai notifikasi aktif” + daftar recent + tombol Simpan manual  
**Batasan sadar (by design / sisa backlog):**

- **Foreground service (Fase 1):** `lib/services/foreground_track.dart` menjaga proses hidup selama `track_master` ON + session aktif (Android saja, service type `specialUse`), mati saat master OFF / logout. Start/stop dipanggil dari `main.dart` (init), `notif_settings` (toggle), `main_shell` (init/resume), `other_screen` (logout). Gate `_onEvent` TIDAK berubah karenanya. Izin Manifest (`FOREGROUND_SERVICE_SPECIAL_USE` + service) di-inject CI (`apk.yml`); `android/` tidak di-commit. OEM agresif masih bisa kill → status jujur via `ForegroundTrack.isRunning`, jangan janji "selalu aktif".
- Plugin **tidak mengekspos timestamp notif asli** → tanggal = waktu diterima event.
- Isi pesan full **tidak diupload**; yang dikirim: amount, type, package, hash, category, note, date, wallet_id.

### 4.6 Budget & laporan
- Budget per kategori per bulan (`budgets`: org_id, category, month, limit_amount).
- Progress spent dari transaksi `type=out` bulan berjalan, grouping `category` (null → “Lainnya”).
- Laporan: filter bulan, total in/out, export CSV + PDF via share_plus.

### 4.7 Design system
- Lihat `DESIGN.md` — wajib dipatuhi untuk UI baru.
- **Font global (2.3.9+22):** Plus Jakarta Sans (`SsrFonts.body`, semua layar) + Anton (`SsrFonts.display`, wordmark) + Phosphor Fill (`SsrFonts.icon`, layar intro) — dibundel di `assets/fonts/`, tetap jalan offline. Jangan tambah `fontFamily` hardcoded (kecuali monospace kode invite yang sengaja).
- Uang selalu `rp()` + `FontFeature.tabularFigures`.
- Aksen zamrud `#0F766E`, danger bata `#B3261E`, kertas `#FAFAF7`.
- Bottom nav 5 tab; reload beranda/budget/laporan tiap pindah tab (`MainShell._select`).

### 4.8 Build & release
- Push `main` → Actions: `flutter pub get` → generate `android/` bila belum → inject NotificationListenerService ke Manifest → `flutter analyze` (wajib 0 issue, tambahan Fase 2 D1) → `flutter test` → inject signing dari secrets → `flutter build apk --release --dart-define=SUPABASE_*` → upload artifact.
- Secrets: `SSR_KEYSTORE_B64`, `SSR_KEYSTORE_PASS`, `SSR_KEY_ALIAS`, `SSR_KEY_PASS`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
- Folder `android/` **tidak di-commit** (di-generate CI).

### 4.9 Fase 2 hardening (v2.3.7+20)

- **A3 rate limit auto-insert:** trigger `before insert` di `transactions` (`supabase/migration_11_hardening.sql`) — maks **10 auto-insert (`source_package != null`) / 60 detik / org**, index partial pendukung. Lewat batas → `raise 'RATE_LIMITED'`. Client: `saveErrorStatus()` (`notif_track_service.dart`) → status recent **"Dibatasi, terlalu banyak. Coba lagi."** (dipakai di `_onEvent` + `forceSave`). Insert form manual tidak kena limit.
- **A4 audit log:** tabel `audit_logs` + trigger SECURITY DEFINER: `tx_auto_insert` (meta: tx_id, amount, type, package, date) dan `org_join` (meta: role). RLS: SELECT member saja, **tanpa** INSERT/UPDATE/DELETE client. Tanpa UI (baca via Dashboard).
- **Error monitoring in-house:** `lib/services/error_reporter.dart` — `ErrorReporter.init()` di `main()` (`FlutterError.onError` + `PlatformDispatcher.onError` + `runZonedGuarded`), `capture()` dipanggil di catch pipeline notif/backup. Anti-flood murni Dart: dedupe `context|message` per 60 menit + maks 20 event/jam, gagal upload = drop senyap. Tabel `client_errors` (RLS tulis+baca milik sendiri). **Tanpa PII**: hanya message/stack/context/`app_version` (`AppInfo.version`, ikut bump pubspec).
- **D5 backup manual:** Lainnya → **Cadangkan data** → 3 CSV (`dompet/transaksi/budget-ssr-space.csv`) via share sheet. Builder murni di `lib/services/backup_export.dart`. Tanpa jadwal otomatis (pg_cron = backlog Fase 3).

### 4.10 Fase 3 (mulai 2026-09-25) — scale ops

- **Cek limit plan Supabase (spike):** free plan 2026 = 500 MB DB, 5 GB egress, 50k MAU, 500k edge fn invocations, max 2 project; **project pause setelah 7 hari inaktif** (diperketat 2026-02-01) — cegah via aktivitas harian DB/API atau email warning Supabase. Rekomendasi + trigger naik Pro: lihat AUDIT §4.
- **D4 supply chain:** `.github/dependabot.yml` (github-actions, weekly, digroup jadi 1 PR) + semua action di `apk.yml` **di-pin ke commit SHA** dengan komentar versi (dependabot yang update). D2 ikut selesai: `checkout` v4→**v7.0.1**, `setup-java` v4→**v6.0.1**, `flutter-action`→**v2.23.0**, `upload-artifact` v4→**v7.0.1**. SHA via `git ls-remote` (jangan pernah karangan).
- **F3-c test RLS server-side:** workflow `.github/workflows/rls-test.yml` (trigger push `supabase/**` + PR + manual) → service `postgres:16` → `supabase/test/run.sh` = `setup.sql` (stub role `anon`/`authenticated`/`service_role` + schema `auth` + `auth.uid()` baca GUC `test.user_id` + default privileges) → `schema.sql` → `migration_02..12` → `rls_test.sql` (assert T01–T11: regresi recursion, isolasi baca/tulis lintas org, join org korban, mint_tx_code, rate limit, audit log, client_errors, invite hash/idempoten/exhausted/anon, tx_sequences, wallet_balance). `migration_13` dilewati harness (butuh pg_cron). **Jalankan lokal:** `SSR_RLS_DB_URL=postgresql://… bash supabase/test/run.sh`.
- **Temuan test → `migration_12_join_fixes.sql` (wajib user jalankan):** [P0] bikin workspace baru gagal sejak migration_07 (subquery `organizations` di policy kena RLS "member read org" → chicken-and-egg; fix helper `is_org_creator` SECURITY DEFINER); [minor] `join_org_by_invite` cek EXHAUSTED sebelum idempoten → re-join member selalu error (urutan cek dibetulkan).
- **F3-d retention + backup:** `migration_13_retention.sql` (pg_cron, idempotent: `client_errors` 30 hari, `audit_logs` 180 hari, `cron.job_run_details` 14 hari — anti warning upgrade Supabase) + workflow `backup-db.yml` (cron Senin 02:00 UTC + manual; pg_dump via container `postgres:18-alpine` → artifact 30 hari; **butuh secret `SUPABASE_DB_URL`**, kalau kosong job skip dengan warning, bukan gagal). **Status akhir 2026-09-25:** migration_12 + 13 sudah user jalankan; secret diset (session pooler URI) → run `36110689118` hijau, artifact `ssr-space-backup` 63 KB.

### 4.11 Privacy mode — samarkan nominal (2026-09-25)

- **State:** prefs `mask_amounts` (default OFF) + `ValueNotifier` global `maskAmounts` di `lib/utils/mask.dart`; dimuat di `main()` via `loadMaskAmounts(prefs)`.
- **Format:** `amt(value)` → `rp(value)` bila mati, placeholder `Rp ••••••` bila menyala. `mask.dart` me-`export` `money.dart` (jadi `rp` tetap tersedia).
- **Rebuild global:** `MainShell.body` dibungkus `ValueListenableBuilder(maskAmounts)` → toggle langsung bikin semua tab ulang-build tanpa reload data.
- **Titik pakai:** beranda (surplus + masuk/keluar), transaksi (list via `TxRow` + label dropdown dompet), dompet (saldo + total), budget (spent/limit), laporan (in/out/net), recent notif. **Billing sengaja tetap `rp()`** (harga plan app, bukan uang user).
- **Toggle:** ikon mata di `AppBar` Beranda (`lib/widgets/mask_toggle.dart`) + tile **Tampilan → Samarkan nominal** di Lainnya. Billing/field input form tidak ikut disembunyikan.
- **Test:** `test/mask_test.dart` (asli/menyamar + default OFF + persist prefs).

### 4.12 Refactor struktur lib/ + widget bersama (2026-09-25)

**Hard constraint: struktur saja — pixel, warna, spacing, font, behavior wajib identik.**

- **Fase A** (`112c64d`, CI run `36123125093` hijau): `lib/core/{saas,session,format,theme}` → `lib/{services,utils,theme}` + `lib/screens/<fitur>/` (auth, shell, beranda, transaksi, dompet, budget, laporan, lainnya, workspace). Import-only, nol ubah kode.
- **Fase B** (`19e979d`): 5 widget baru — `NavTile`, `WalletRow`, `BankTrackRow`, `LabeledSectionCard`, `TxTypeSelector` — plus dekomposisi `build()` besar per layar dan dedup `_orgId`/`activeOrgId` → `lib/utils/org_prefs.dart`. **Re-use wajib** 5 widget lama (`SectionCard`, `StatusChip`, `TxRow`, `PrimaryButton`, `PinField`) — dilarang bikin duplikat paralel.
- **Fix Fase B** (`33dcd31`): 2 error analyze — `nav_tile` `Text(String?)` (String? tak otomatis promote) dan `RecentNotifTile._saveButton/_pickTypeAndSave` yang akses `context` di luar `build` → `BuildContext` dilewatkan eksplisit. CI run `36126303610` hijau penuh (analyze → test → APK `2.3.9+22-refactor`).
- **Fase E (2026-09-25, SELESAI):** bedah sisa `build()` >50 baris di 10 layar — `transactions` (`6673fd6`), `notif_settings` (`669b540`), `billing` (`0508afc`), `reports` (`1ad05f3`), `auth`+`wallets` (`836d9ac`), `org_switcher`/`splash`/`main_shell`/`onboarding` (`066ef76`…`21a46f1`). Semua `build()` layar kini <50 baris; **3 widget lama di-scope out** (`pin_field` 72, `tx_row` 69, `bank_track_row` 54 — kohesif, wajar). Run batch akhir `36133546126` hijau → APK `SSR-SPACE-2.3.9-22-fasee-bedah-build.apk`. Detail ekstraksi per layar: AUDIT §4 "Fase E".
- **Aturan tambah widget baru:** cek dulu isi `lib/widgets/` (12 file); nominal wajib lewat `amt()`; nilai styling harus **persis** sama — beda satu angka pun = jangan digabung (parameterisasi eksplisit atau pisah).
- **Verifikasi:** `flutter` tak ada di Termux → bukti = CI analyze/test hijau + screenshot before/after manual di device user (tiap layar yang disentuh).

### 4.13 Polish visual "Fintech Ledger" (2026-09-25, staged — belum commit)

Visual-only 8 layar (detail: AUDIT §4 "Polish visual"). Fondasi: `phosphor_flutter`/`flutter_svg`/`lottie`/`skeletonizer`, `fl_chart`→1.2.0, Fraunces bundel (`SsrType`), `AppIcons` duotone (render via `PhosphorIcon`). Empty berilustrasi (copy UD identik), sukses Lottie `check_pop`, donut Laporan (mask-aware), gauge Budget, hero SURPLUS ber-shadow+sheen, 7 skeleton ganti spinner. Aset sumber: `/sdcard/Assets/SSR-SPACE-polish/`. Semua `build()` <50; copy Indonesia identik; `notif_track_service`/auth/Supabase tak disentuh. CI (analyze→test→APK) + APK ke `/sdcard/Download/SSR-SPACE/` jalan setelah user bilang "commit".
- **Hasil CI (`b89d797`…`80fce1f`, run `36148631602` hijau):** analyze 0 issue, 60 test lulus, APK `SSR-SPACE-2.3.9-22-polish-ledger.apk`. Temuan: `phosphor_flutter` 2.1.0 tak kompatibel stable (`IconData` final) → **font `Phosphor-Duotone.ttf` divendor** (`assets/fonts/`, family `PhosphorDuotone`), ikon via `AppIcons`+`DuoIcon` mandiri, dep dilepas. Pola const baru: field `static const`, `const` hanya di call-site full-const (lihat AUDIT §7).

---

## 5. Struktur repo (penting)

```
SSR SPACE/
├── AGENTS.md                 ← file ini
├── AUDIT.md                  ← audit + backlog detail
├── DESIGN.md                 ← arah visual (wajib)
├── README.md
├── pubspec.yaml
├── assets/fonts/             ← PJS variable + Anton + Phosphor-Fill (bundled)
├── .github/workflows/        ← apk.yml, rls-test.yml, backup-db.yml
├── lib/
│   ├── main.dart
│   ├── theme/       (app_theme: SsrColors, SsrSpace, SsrRadius, SsrFonts)
│   ├── utils/       (money/rp, datetime/ymd, mask/amt, org_prefs, app_info)
│   ├── services/    (auth, wallet, transaction, budget, dashboard,
│   │                 notif_parse, notif_track_service, invite_service,
│   │                 invite_token, foreground_track, supabase_config,
│   │                 session_service, error_reporter, backup_export,
│   │                 tx_input_logic (murni, numpad + tanggal/jam), …)
│   ├── models/      (wallet, transaction, wallet_balance)
│   ├── screens/     ← satu folder per fitur:
│   │   ├── auth/    (splash, intro_consent, auth, lock, onboarding)
│   │   ├── shell/   (main_shell)
│   │   ├── beranda/ transaksi/ dompet/ budget/ laporan/
│   │   ├── lainnya/ (other, notif_settings, billing)
│   │   └── workspace/ (invite, org_switcher)
│   └── widgets/     (section_card, status_chip, tx_row, primary_button,
│                     pin_field, nav_tile, wallet_row, bank_track_row,
│                     labeled_section_card, tx_type_selector, mask_toggle,
│                     month_picker, state_views, tx_numpad, tx_input_sheet)
├── test/            (session, notif_parse, notif_track, budget, dashboard, …)
├── supabase/
│   ├── schema.sql
│   ├── migration_02 … migration_13
│   ├── test/        (run.sh, setup.sql, rls_test.sql — CI rls-test.yml)
│   └── functions/create-snap/
└── docs/superpowers/ (spec + plan historis)
```

> **Catatan path:** struktur di atas berlaku sejak refactor 2026-09-25 (`112c64d` + `19e979d`).
> Spec lama di `docs/superpowers/specs/` masih menulis path lama (`lib/core/saas/…`,
> `lib/screens/*_screen.dart`) — jangan ditiru, cek struktur di atas.

---

## 6. Perintah berguna

```bash
# status & log
git status && git log --oneline -15

# commit + push + pantau CI
git add -A && git commit -m "feat: …" && git push origin main
gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status

# unduh APK terbaru
gh run download <run-id> -n ssr-space-apk -D /sdcard/Download/SSR-SPACE/

# cek SS (screenshot) terbaru dari user — bukti bug / package app / UI device
ls -t /sdcard/DCIM/Screenshots | head -5
# → lalu read file terbaru namanya Screenshot_<YYYY-MM-DD-HH-MM>... ; jangan nebak isi SS tanpa buka

# lokal: flutter TIDAK terpasang di Termux ini → test jalan di CI saja
```

---

## 7. Aturan kontribusi / agent

1. **Bahasa commit:** `feat:` / `fix:` / `chore:` / `design:` + deskripsi singkat EN atau ID konsisten.
2. **UI baru** → ikuti `DESIGN.md` + cek `antislop` bila ada sesi UI.
3. **Ubah RLS / SQL** → tulis migration baru (`migration_09_…`), jangan edit history; update `README` urutan; ingatkan user jalankan di Supabase.
4. **Jangan** hardcode secret di repo.
5. **Jangan** policy org_members self-recursive.
6. **Test** untuk logic murni (parse, hash, budget math) wajib; jalankan via CI.
7. File deliverable → `/sdcard/Download/SSR-SPACE/`.
8. Konfirmasi sebelum commit besar / push kalau user belum minta.

---

## 8. Kontak / environment

- HP: Termux Android, working dir home.
- `dart` ada lokal; **`flutter` tidak** — analyze/test = CI.
- `gh` CLI ter-login ke `Sendysyah27`.

<!-- antislop:start -->
## antislop
For UI, copy, people, mobile layout, or code comments work, read `antislop.md` (core) and then the skill for the task:
- UI / visual: `skills/antislop-ui/SKILL.md`
- Copy & text: `skills/antislop-copywriting/SKILL.md`
- People / accessibility: `skills/antislop-human/SKILL.md`
- Mobile / responsive: `skills/antislop-layoutmobile/SKILL.md`
- Code comments: `skills/antislop-code/SKILL.md`
Before starting, ask the user when antislop applies: during the work, or after it is done.
<!-- antislop:end -->
