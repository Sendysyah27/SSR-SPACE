# AGENTS.md — SSR SPACE

Panduan kerja untuk agent / contributor di repo ini. Baca dulu sebelum ubah kode.

---

## 1. Identitas projek

| | |
|---|---|
| Nama | **SSR SPACE** |
| Path | `/data/data/com.termux/files/home/SSR SPACE` |
| Remote | `https://github.com/Sendysyah27/SSR-SPACE.git` |
| Versi | `2.3.6+19` (`pubspec.yaml`) |
| Stack | Flutter (stable) + Supabase (Auth + Postgres RLS) + Notification Listener |
| Bahasa UI | Indonesia |
| Build | GitHub Actions (`.github/workflows/apk.yml`), **bukan** lokal Termux |
| APK hasil | artifact `ssr-space-apk` di run Actions terakhir |
| Package id | `com.ssr.space.ssr_space` (`ownPackage` di `notif_track_service.dart`) |

**Bukan lagi app offline sqflite penuh.** Storage utama = Supabase cloud per workspace. Spec lama di `docs/superpowers/specs/` sebagian basi — lihat bagian update di situ (ada catatan 2026-09-24).

---

## 2. Tujuan produk (goal)

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
| Fase 2 | Hardening: rate limit auto-insert (A3), audit log (A4), error monitoring, backup DB (D5), `flutter analyze` di CI (D1) | ⬜ |
| Fase 3 | Scale ops: cek limit plan Supabase, dependabot/pin actions SHA (D4), test RLS server-side | ⬜ |
| Fase 4 | Monetisasi: billing Midtrans per plan + limit kuota | ⬜ |

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
8. **SELESAI → wajib catat hasil kerja di AGENTS.md (status/fitur) + AUDIT.md (changelog §7)** — jangan diakhiri sebelum doc diupdate
```

**Jangan commit tanpa diminta user** (peraturan global HP ini), kecuali user sudah bilang “commit” / “lanjut push”.

**Aturan wajib (2026-09-25):** setiap pekerjaan yang sudah selesai (fix, fitur, redesign, migration) **harus dibaca ulang doc-nya lalu dicatat** di `AGENTS.md` + `AUDIT.md` — minimal changelog commit di AUDIT.md §7 dan baris status terkait di AGENTS.md. Doc boleh tertinggal ≤1 sesi, jangan lebih.

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
```

**Aturan RLS (jangan dilanggar):**
- Policy SELECT di `org_members` **TIDAK BOLEH** subquery ke `org_members` lagi → infinite recursion.
- Cek owner/admin pakai helper `public.is_org_admin(org_id)` (SECURITY DEFINER).
- Semua akses data org lewat `exists (select from org_members where org_id=... and user_id=auth.uid())` di tabel tsb.
- Policy di **`org_invites`** juga wajib lewat `is_org_admin` saja — jangan subquery `org_members`.
- Join workspace lain **HANYA** lewat RPC `join_org_by_invite`; jangan bikin jalur insert `org_members` baru selain `join own org` (created_by) dan RPC itu.
- `org_invites` menyimpan **hash sha256 token** saja, tidak pernah token asli.

---

## 4. Fitur yang telah update (detail per 2026-09-25, v2.3.6+19)

### 4.1 Sesi & auth
- Splash → (opsional onboarding PIN) → Auth email/password Supabase → pilih/buat workspace → `MainShell`.
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

**Allowlist package** (`lib/core/saas/notif_parse.dart`) — match `package == prefix` atau `startsWith(prefix + '.')`:

| Label | Prefix package |
|-------|----------------|
| myBCA | `com.bca.mybca` |
| BCA | `com.bankcentralasia`, `com.bca.main` |
| Livin Mandiri | `com.mandiri.mobile`, `com.bankmandiri` |
| DANA | `id.dana` |
| OVO | `com.vnoo.ovo`, `com.ovo` |
| GoPay | `com.gojek.app`, `com.gojek.gojek` |
| ShopeePay | `com.shopee` |
| SeaBank | `com.seabank`, `id.co.seabank` |
| BRI | `com.bri.brimo`, `id.co.bri.brimo`, `com.bri.browser` |
| BNI | `com.bni`, `id.co.bni` |
| BTN | `com.btn`, `id.co.btn` |
| Jenius | `com.btpn`, `id.co.btpn` |
| Jago | `id.co.jago`, `com.bankjago` |
| Blu | `com.bca.digital`, `id.co.bca.blu` |
| CIMB | `com.cimb`, `com.octo` |
| KEB Hana | `id.co.bankbkemobile`, `id.co.bankbke`, `id.co.kebhana` |
| ISAKU | `com.isaku` |

Urutan list penting: **myBCA sebelum BCA**.

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

- **Foreground service (Fase 1):** `lib/core/saas/foreground_track.dart` menjaga proses hidup selama `track_master` ON + session aktif (Android saja, service type `specialUse`), mati saat master OFF / logout. Start/stop dipanggil dari `main.dart` (init), `notif_settings` (toggle), `main_shell` (init/resume), `other_screen` (logout). Gate `_onEvent` TIDAK berubah karenanya. Izin Manifest (`FOREGROUND_SERVICE_SPECIAL_USE` + service) di-inject CI (`apk.yml`); `android/` tidak di-commit. OEM agresif masih bisa kill → status jujur via `ForegroundTrack.isRunning`, jangan janji "selalu aktif".
- Plugin **tidak mengekspos timestamp notif asli** → tanggal = waktu diterima event.
- Isi pesan full **tidak diupload**; yang dikirim: amount, type, package, hash, category, note, date, wallet_id.

### 4.6 Budget & laporan
- Budget per kategori per bulan (`budgets`: org_id, category, month, limit_amount).
- Progress spent dari transaksi `type=out` bulan berjalan, grouping `category` (null → “Lainnya”).
- Laporan: filter bulan, total in/out, export CSV + PDF via share_plus.

### 4.7 Design system
- Lihat `DESIGN.md` — wajib dipatuhi untuk UI baru.
- Uang selalu `rp()` + `FontFeature.tabularFigures`.
- Aksen zamrud `#0F766E`, danger bata `#B3261E`, kertas `#FAFAF7`.
- Bottom nav 5 tab; reload beranda/budget/laporan tiap pindah tab (`MainShell._select`).

### 4.8 Build & release
- Push `main` → Actions: `flutter pub get` → generate `android/` bila belum → inject NotificationListenerService ke Manifest → `flutter test` → inject signing dari secrets → `flutter build apk --release --dart-define=SUPABASE_*` → upload artifact.
- Secrets: `SSR_KEYSTORE_B64`, `SSR_KEYSTORE_PASS`, `SSR_KEY_ALIAS`, `SSR_KEY_PASS`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
- Folder `android/` **tidak di-commit** (di-generate CI).

---

## 5. Struktur repo (penting)

```
SSR SPACE/
├── AGENTS.md                 ← file ini
├── AUDIT.md                  ← audit + backlog detail
├── DESIGN.md                 ← arah visual (wajib)
├── README.md
├── pubspec.yaml
├── .github/workflows/apk.yml
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── format/  (money, datetime)
│   │   ├── saas/    (auth, wallet, transaction, budget, dashboard,
│   │   │             notif_parse, notif_track_service, invite_service,
│   │   │             invite_token, foreground_track, supabase_config, …)
│   │   ├── session/ (session_service, PIN)
│   │   └── theme/
│   ├── models/      (wallet, transaction)
│   ├── screens/     (splash…main_shell, beranda, transactions, notif_settings, …)
│   └── widgets/
├── test/            (session, notif_parse, notif_track, budget, dashboard, …)
├── supabase/
│   ├── schema.sql
│   ├── migration_02 … migration_10
│   └── functions/create-snap/
└── docs/superpowers/ (spec + plan historis)
```

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
