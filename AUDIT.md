# AUDIT.md — SSR SPACE

Audit keamanan & kualitas fitur **auto-track notifikasi bank / dompet digital**.  
Tanggal audit: **2026-09-24** · Versi saat audit: 2.3.2+14 → dieksekusi sampai **2.3.6+19**.  
Lensa: OWASP / RLS Supabase / input hostile (isi notif pihak ketiga).

**Update 2026-09-24/25 (sesi lanjutan):**
- Bug **input manual gagal** (`date` null eksplisit → default `current_date` tak dipakai) fixed di `385489a` + test `tx_payload_test.dart`.
- **Redesign UI/UX** anti-slop selesai (`a0cf623`): dial `ENERGY 2 / RHYTHM 2 / MOTION 2`, 5 widget baru (`SectionCard`, `StatusChip`, `TxRow`, `PrimaryButton`, `PinField`), 16 layar diredesain, `dashboard_screen` dihapus (dead code), kontras hero zamrud diperbaiki (WCAG AA). Delivery Gate antislop PASS.
- Fix build CI (`4693c88`): `ExtendedFloatingActionButton` sudah tak ada di Flutter stable + `NavigationBar` tak punya param `iconTheme` (dipindah ke `NavigationBarTheme`). **Pelajaran: `flutter test` tak menangkap error layar yang tak di-import test; `flutter build apk` wajib hijau sebelum dibilang selesai.**
- **BRI**: diverifikasi user di device → deteksi notif **aman** (sebagian A6).
- **Bug sisa belum diidentifikasi** — BRI lolos tapi user masih melaporkan bug; detail + root cause = sesi baru.
- APK rilis: `/sdcard/Download/SSR-SPACE/SSR-SPACE-2.3.5-18-redesign.apk`
- **Fase 1 scale** (invite workspace + foreground service): kode + docs commit lokal; CI milestone 1 run `36069820717` dan milestone 2 run `36075349074` hijau. Changelog commit di §7.
- APK rilis Fase 1: `/sdcard/Download/SSR-SPACE/SSR-SPACE-2.3.6-19-fase1-scale.apk` (diunduh dari run CI setelah push docs ini)
- **Fase 2 D1** (2026-09-25): CI kini wajib lulus `flutter analyze` sebelum test; 26 temuan lama dibersihkan sekali jalan (`739fbb4` + `e7e88e8`), run `36090886163` hijau penuh (analyze → test → APK).
- **Fase 2 hardening** (2026-09-25): A3 rate limit auto-insert + A4 audit log (`migration_11_hardening.sql`), error monitoring in-house (`client_errors` + `ErrorReporter`), D5 backup manual multi-CSV. CI run `36098447278` hijau penuh; APK `SSR-SPACE-2.3.7-20-fase2-hardening.apk`. **User wajib jalankan migration_11 di Supabase.**
- **Fase 3 awal** (2026-09-25): spike limit plan Supabase (hasil §4) + D4 dependabot & pin actions by SHA (D2 sekalian selesai).
- **A0 bug sisa pasca-redesign — SELESAI** (2026-09-25): root cause = **prefix package salah**. App **SeaBank** (Play Store) pakai `id.co.bankbkemobile.digitalbank` → kena label "KEB Hana"; **KEB Hana asli** (`co.id.myhana.app`) tidak terpantau sama sekali. Fix: pindahkan prefix BKE (`id.co.bankbkemobile`, `id.co.bankbke`) ke SeaBank, KEB Hana → `id.co.kebhana` + `co.id.myhana.app`, test dibalik. **Fitur baru: privacy mode "Samarkan nominal"** (`mask.dart` + `amt()`, toggle mata di Beranda + tile Lainnya, `test/mask_test.dart`).
- **Fase 3 F3-c/F3-d** (2026-09-25): **test RLS server-side di CI** (`rls-test.yml` + `supabase/test/`, 40+ assert, lulus lokal + CI) → **nemukan 2 temuan** → `migration_12_join_fixes.sql` (**[P0] bikin workspace baru gagal sejak migration_07** — subquery `organizations` di policy `join own org` kena RLS "member read org" (chicken-and-egg); + [minor] `join_org_by_invite` cek EXHAUSTED sebelum idempoten); **F3-d**: `migration_13_retention.sql` (pg_cron retention) + `backup-db.yml` (pg_dump mingguan, butuh secret `SUPABASE_DB_URL`). **Migrasi 12 + 13 sudah dijalankan user (2026-09-25)**; secret `SUPABASE_DB_URL` diset → backup mingguan aktif (run `36110689118` hijau, artifact 63 KB).
- **Sesi tagline + intro consent + font premium** (2026-09-25, v2.3.9+22): tagline resmi **"Simple. Secure. Reliable. Your Finance Space."** (kata Offline dibuang; D3 pubspec description ditutup); **IntroConsentScreen** carousel 4 halaman + checkbox persetujuan (prefs `consent_v1`, gate di splash sebelum workspace); **font global** Plus Jakarta Sans + Anton (wordmark) + Phosphor Fill (intro) dari `sdcard/Assets/` → `assets/fonts/`; DESIGN.md tipografi/ikon ditulis ulang. Changelog commit di §7.

---

## Ringkasan eksekutif

| Area | Sebelum | Sesudah (commit `9634116`…`d4aec58`) |
|------|---------|----------------------------------------|
| Join workspace | User manapun bisa insert `org_members` utk org apa pun | Hanya pembuat (`created_by`) atau owner/admin via `is_org_admin` |
| `mint_tx_code` | SECURITY DEFINER tanpa authz | Wajib member org tsb |
| Mapping dompet | Notif otomatis **tanpa** `wallet_id` | Pref per-app + auto-match nama wallet |
| Kategori | = nama app (`DANA`) | Pref `track_cat_*`, default null |
| Tanggal transaksi | Selalu `current_date` server | `date` = hari saat notif diterima |
| Match app | Substring bebas | Allowlist **prefix package** |
| Dedup hash | Permanen (tanpa hari) | Per **hari** + content + package |
| Urutan TX code | Mint dulu → insert bisa gagal → lubang nomor | Insert dulu → mint → update |
| Regression 07 | — | Policy SELECT org_members self-ref → recursion dompet → **migration_08** |

**Status CI setelah fix:** green · 11 file test · APK `ssr-space-apk` sukses (build `4693c88`).

---

## 1. Peta ancaman auto-track (threat model singkat)

### Trust boundary
| Boundary | Arah data | Risiko |
|----------|-----------|--------|
| Notifikasi Android → app | Hostile text (attacker bisa push notif dari app mirip nama) | Salah nominal, salah jenis, spam insert |
| App → Supabase (anon key + user JWT) | Semi-trusted client | IDOR org, tulis lintas workspace |
| Supabase RLS | Server-side gate | Policy salah = bocor massal |
| Isi notif ke UI recent | Local only | Screenshot / screen share bocor PII transaksi |

### Aset
- Saldo & mutasi nyata user (wallets, transactions)
- Membership workspace (org_members)
- Sequence kode TX
- Token keystore release (CI secrets — sudah benar di GitHub Secrets)

### STRIDE ringkas
| T | Temuan | Mitigasi sekarang |
|---|--------|-------------------|
| Spoofing | App package mirip bank | Allowlist prefix; masih bisa typosquat prefix panjang → monitor |
| Tampering | Insert tx org lain | RLS member-only + `created_by` join |
| Repudiation | “Saya tidak catat itu” | `source_package`, `source_hash`, `note` “Otomatis dari X”; belum ada audit log server |
| Info disclosure | Baca tx org lain | RLS + **migration_08** hilangkan recursion / policy longgar |
| DoS | Flood notif → insert | Unique hash/hari; **belum** rate limit |
| Elevation | Join org korban; mint code org lain | Fixed P0 |

---

## 2. Temuan detail & status

### P0 — Keamanan (SELESAI)

#### A1. RLS join org terlalu longgar
**Lokasi (lama):** `migration_02` / `schema.sql`  
`with check (user_id = auth.uid())` tanpa cek siapa yang boleh join.

**Eksploitasi:** attacker login → `insert into org_members (org_id=victim, user_id=self, role=member)` → RLS `member wallets` / `member tx` lolos → baca/tulis buku kas korban (termasuk hasil auto-track).

**Fix:** `migration_07_security.sql`
- kolom `organizations.created_by`
- insert org: `created_by = auth.uid()`
- insert membership: self jika pembuat, ATAU `public.is_org_admin(org_id)`

**Verifikasi:** user lama tanpa `created_by` di-backfill dari owner pertama.

#### A2. `mint_tx_code` tanpa authorization
**Lama:** siapa pun `authenticated` bisa `rpc('mint_tx_code', {p_org_id: org_lain})` → increment sequence korban.

**Fix:** di dalam function  
`if not exists (select from org_members where org_id=p and user_id=auth.uid()) then raise …`

#### A3. RLS recursion (regression setelah 07)
**Gejala:** app → Dompet → **“Gagal memuat dompet. Periksa koneksi.”**  
**Akar:** policy  
`member read org_members` USING `(… or exists (select from org_members …))`  
→ Postgres re-enter policy → *infinite recursion detected in policy for relation org_members* → query `wallets` (RLS-nya juga baca `org_members`) ikut gagal.

**Fix:** `migration_08_fix_rls_recursion.sql`
1. `drop policy "member read org_members"`
2. SELECT cukup `own memberships` (`user_id = auth.uid()`)
3. Helper `is_org_admin(uuid)` SECURITY DEFINER untuk INSERT join
4. Error UI wallets kini menyebut recursion bila masih terjadi

**Lesson (wajib di AGENTS):**  
> Jangan pernah bikin policy SELECT `org_members` yang subquery ke `org_members`.

---

### P1 — Integritas auto-track (SELESAI di `9634116`)

#### B1. Transaksi otomatis tidak nempel dompet
`notif_track_service` dulu insert tanpa `wallet_id`.

**Fix:**
- Pref `track_wallet_<Label>` (dropdown di Pengaturan pelacakan)
- Fallback: cocok `wallet.name` mengandung label / alias (`myBCA`→BCA, `Livin Mandiri`→Mandiri, …)
- Status bila gagal: `Tersimpan (dompet belum cocok)`

#### B2. Kategori = nama aplikasi
`category: appLabel` → budget “Makan” tidak kena; muncul budget aneh “DANA”.

**Fix:** `category` dari `track_cat_<Label>` (opsional). Default `null` → agregat “Lainnya”.  
Note tetap `Otomatis dari <Label>`; sumber app via `source_package`.

#### B3. Tanggal selalu hari ini (server)
**Fix:** kirim `date: ymd(capture.at)`.  
**Limitasi:** plugin tidak kasih `when` notif asli → “hari ini” = saat event diterima. Scan ulang shade lama bisa salah hari → backlog parse tanggal dari teks / ganti plugin.

#### B4. Match package substring
Dulu: `p.contains('dana')`, `contains('blu')`, `contains('btn')` → `com.example.danagame`, bluetooth, dll ikut.

**Fix:** `WatchedApp.packagePrefixes` + `==` atau `startsWith(prefix + '.')`.  
Test: `com.example.danagame` → null; `com.bluetooth…` → null; `id.dana.debug` → DANA.

**Sisa risiko:** prefix masih bisa terlalu umum (`com.shopee`, `com.bri.browser`) — audit prefix vs package asli rilis Play Store perlu diverifikasi di device.

#### B5. Dedup hash tanpa waktu
Dulu: `sha256(pkg|title|content)` unique per org → notif promo identik besok ditolak.

**Fix:** `sha256(YYYY-MM-DD|pkg|title|content)`.

#### B6. Burn sequence TX
Dulu: `mintCode()` → `add()`; insert gagal (23505 / RLS) → nomor hilang.

**Fix:** `TransactionService.add`:
1. insert tanpa code  
2. bila `code == null` → mint → `update set code`  
3. kegagalan mint ditelan (transaksi tetap ada)

---

### P2 — Kualitas (SELESAI sebagian)

| ID | Temuan | Status |
|----|--------|--------|
| C1 | Field `createdAt` tanpa init constructor | ✅ model lengkap + `fromMap created_at` |
| C2 | Helper `dayLabel`/`txTime` tak terpakai | ✅ dipakai beranda |
| C3 | Test hanya parse amount | ✅ + hash hari, allowlist, ymd, CapturedNotif, pref key |
| C4 | Spec docs bilang offline sqflite | ✅ header spec diupdate |
| C5 | `forceSave` skip gate amount≤0 | ✅ dipersempit; master toggle masih bisa “manual save” (by design) |
| C6 | Input manual gagal “Gagal menyimpan” (2.3.4+) | ✅ `385489a`: `txInsertPayload` selalu isi `date` (default hari ini), error Postgrest transparan, test `tx_payload_test.dart` |
| C7 | Build APK gagal di CI padahal test hijau | ✅ `4693c88`: API Flutter stable (`FloatingActionButton.extended` + `NavigationBarTheme`) |

---

### P3 — Terbuka (belum dikerjakan)

Lihat **Backlog** di bawah.

---

## 3. Pipeline auto-track (referensi kode)

```
lib/main.dart
  SupabaseConfig.init()
lib/screens/shell/main_shell.dart:26
  NotifTrack.ensureListening()
lib/services/notif_track_service.dart
  notificationsStream → _onEvent
lib/services/notif_parse.dart
  matchWatchedApp / parseNotifAmount / classifyNotif / notifHash / ymd
lib/services/transaction_service.dart
  add() → insert → mint_tx_code → update code
lib/screens/lainnya/notif_settings_screen.dart
  master + per-app + wallet mapping + recent + forceSave
supabase/migration_06_notif_source.sql
  source_package, source_hash, unique_tx_hash
supabase/migration_07 + 08
  RLS join + is_org_admin + drop recursion policy
```

### Gate `_onEvent` (order)
1. `hasRemoved` → skip  
2. package kosong / == `com.ssr.space.ssr_space` → skip  
3. `matchWatchedApp == null` → status “Bukan app terpantau”  
4. `track_master` false → skip  
5. `track_<Label>` false → skip  
6. no session → skip  
7. no `active_org_id` → skip  
8. amount null / ≤0 / type null → skip  
9. resolve wallet + category → `add(...)`  
10. `PostgrestException 23505` → “Sudah pernah dicatat”

---

## 4. Backlog / update lanjutan (jelas & terurut)

### Sprint A — P0/P1 sisa (disarankan berikutnya)

| # | Item | Detail “done when” |
|---|------|---------------------|
| A0 | **Bug sisa pasca-redesign** | ✅ **SELESAI 2026-09-25** — root cause: allowlist salah. SeaBank (`id.co.bankbkemobile.digitalbank`) dilabel "KEB Hana"; MyHana (`co.id.myhana.app`) tak terpantau. Fix di `notif_parse.dart` + test dibalik. Sisa A6 (verifikasi prefix bank lain) terpisah. |
| A1 | **Edit transaksi** (wallet, kategori, tanggal, amount) | ✅ done `2.3.4+16` edit in-place + hapus berkonfirmasi (`transactions_screen`, `TransactionService.update`/`delete`) |
| A2 | **Saldo dompet** | ✅ done `2.3.4+16` view `wallet_balance` (`migration_09`, `security_invoker`); tampil di Dompet + dropdown form |
| A3 | **Rate limit auto-insert** | ✅ done `2.3.7+20`: trigger `before insert` di `transactions` (migration_11), maks 10 auto-insert/60 detik/org → `RATE_LIMITED` → status recent "Dibatasi, terlalu banyak. Coba lagi."; form manual bebas limit |
| A4 | **Audit log server** | ✅ done `2.3.7+20`: tabel `audit_logs` + trigger SECURITY DEFINER `tx_auto_insert` & `org_join` (migration_11); RLS SELECT member saja, client write deny total; tanpa UI (baca via Dashboard) |
| A5 | **Invite workspace** | ✅ done `2.3.6+19` (migration_10, token hash + RPC `join_org_by_invite`); UX Lainnya → Undang anggota |
| A6 | **Verifikasi package Play Store** | Di device: catat `packageName` asli tiap bank di allowlist; perbaiki prefix yang meleset. **BRI ✅ aman (user device, 2026-09-24); SeaBank ✅ + KEB Hana ✅ (Play Store + App info device, 2026-09-25)**; sisa: myBCA/BCA/DANA/OVO/dst |
| A7 | **Bikin workspace baru gagal sejak migration_07** | ✅ ditemukan test RLS F3-c (2026-09-25), fixed `migration_12`: policy `join own org` subquery `organizations` kena RLS "member read org" → 42501 chicken-and-egg; fix helper `is_org_creator` SECURITY DEFINER. Gejala user: "Gagal membuat workspace. Periksa nama dan koneksi." |
| A8 | **Re-join invite selalu INVITE_EXHAUSTED** | ✅ fixed `migration_12`: cek "sudah member" (idempoten) dipindah sebelum cek EXHAUSTED di `join_org_by_invite`; non-member tetap tak lolos tanpa slot |

### Sprint B — Kualitas auto-track

| # | Item | Detail |
|---|------|--------|
| B1 | **Tanggal dari isi notif** | Regex `dd/MM/yyyy` / `yyyyMMdd` di title-content → `date` lebih akurat untuk scan ulang |
| B2 | **Ganti / fork plugin notif** | Plugin sekarang tanpa timestamp; eval `flutter_notification_listener` (ada `timestamp`) atau native |
| B3 | **Foreground service / boot receiver** | ✅ done `2.3.6+19` (`flutter_foreground_task` specialUse, start/stop dari `track_master`) |
| B4 | **Parser nominal lebih cerdas** | Ambil kandidat `Rp` **terakhir** / kandidat terbesar; handle `IDR`; tolak promo “Rp0” |
| B5 | **Classifier dua-arah** | Bila in+out → coba urutkan frasa / minta user pilih di recent (sudah ada Simpan manual) |
| B6 | **Persist recent notif** | Table lokal / prefs agar history tidak hilang restart |
| B7 | **Test integration gate** | Fake event stream → assert insert / skip per gate (mock Supabase) |

### Sprint C — Produk & design

| # | Item | Detail |
|---|------|--------|
| C1 | Transfer antar dompet **leg atomik** di cloud | Saat ini transfer = 1 row type=transfer; perlu 2-leg atau view saldo konsisten |
| C2 | Hapus / edit budget historis bulan lalu | |
| C3 | Grafik dashboard (fl_chart sudah di pubspec, dipakai?) | Pastikan pie/garik sesuai spec lama |
| C4 | Onboarding PIN vs Supabase auth flow | Clarify: PIN lokal masih dipakai parallel? Dokumentasikan |
| C5 | Dark mode / toggle | DESIGN.md mon-light; hanya ship bila diminta + R-34 |
| C6 | Sync offline-first (kembali sqflite + Supabase sync) | Hanya bila user mau offline; berat |
| C7 | **Scan struk DIPARKIR (putusan user 2026-09-29, BELUM eksekusi)** | Wizard catat 2 langkah TETAP; yang dihapus update berikut: `_ScanRow` + dialog sumber + `_pickScanSource` di `tx_input_sheet.dart`, 14 kunci `rcp_*` (kecuali dipakai), dep `google_mlkit_text_recognition` + `image_picker` + `image` (cek `permission_handler` tak ikut). DISIMPAN: `receipt_parse.dart` + `test/receipt_parse_test.dart` (murni, lolos) + spec/plan 2026-09-29. BUKTI: `fromFilePath` NPE native (hanya catch IOException) → bitmap RGBA (gagal decode, stride terbukti BUKAN sebab: guard lolos) → NV21 `fromBytes` TETAP `InputImageConverterError`+NPE `getClass() on null` di 2.8.0+55. Kesimpulan: NPE bukan di konversi gambar, tersangka = load model bundled/minify R8 di device. Investigasi lanjut (bila dibuka lagi): build tanpa minify A/B, atau Cloud Vision via Edge Function proxy (bayar $1.50/1000, butuh backend+kuota). TANPA commit/push untuk ini — digabung update berikut |

### Sprint D — Infra

| # | Item | Detail |
|---|------|--------|
| D1 | CI: `flutter analyze` step | ✅ done 2026-09-25: langkah `flutter analyze` blocking sebelum test (`739fbb4`); 26 temuan lama (5 warning `unawaited_return_in_try_block`, 21 info: deprecation `withOpacity`/`DropdownButtonFormField.value`/`anonKey`, curly braces, unnecessary import, const) dibersihkan di `e7e88e8`; CI run `36090886163` hijau |
| D2 | Setup-java v5 + checkout v5 | ✅ done 2026-09-25 (sekalian D4): `checkout` **v7.0.1**, `setup-java` **v6.0.1** (lewat v5 — versi terbaru 2026), di-pin SHA |
| D3 | Pubspec description masih “offline multi-dompet” | ✅ done 2.3.9+22: description = tagline + realita SaaS (workspace + auto-track), kata "offline" dibuang |
| D4 | Dependabot / pin actions by SHA | ✅ done 2026-09-25: `.github/dependabot.yml` (github-actions, weekly, digroup 1 PR) + 4 action di `apk.yml` di-pin commit SHA + komentar versi (`checkout` v7.0.1, `setup-java` v6.0.1, `flutter-action` v2.23.0, `upload-artifact` v7.0.1) |
| D5 | Backup export DB | ✅ **manual** multi-CSV (dompet/transaksi/budget) dari Lainnya → Cadangkan data (`backup_export.dart`); **otomatis ✅ 2026-09-25**: `backup-db.yml` pg_dump mingguan (cron Senin 02:00 UTC) → artifact 30 hari, butuh secret `SUPABASE_DB_URL` |
| D6 | Retention `client_errors` + `audit_logs` | ✅ done 2026-09-25: `migration_13_retention.sql` (pg_cron harian: `client_errors` 30 hari, `audit_logs` 180 hari, `cron.job_run_details` 14 hari; idempotent). UI baca `audit_logs` opsional tetap backlog |
| D7 | Error monitoring lanjutan | ⬜ Baru: eksplorasi alert/DSN Sentry bila volume error in-house mulai besar |
| D8 | Anti-pause heartbeat free plan | ⬜ Baru: workflow GitHub Actions cron (mis. 2×/minggu) hit query ringan ke project → cegah pause 7 hari (lihat §4 Fase 3). Alternatif: email warning dibaca, atau naik Pro |

### Fase 3 — Cek limit plan Supabase (spike, 2026-09-25)

Sumber: `supabase.com/pricing` + docs *Project Pausing* (nilai 2026; bisa berubah — cek ulang sebelum Fase 4).

| Kuota | Free | Pro ($25/bln) | Pemakaian kita (free, user sedikit) |
|-------|------|---------------|-------------------------------------|
| DB size | 500 MB | 8 GB (+$0,125/GB) | Baris kecil: transaksi/audit/error ~ratusan baris/org → **jauh di bawah** |
| Egress | 5 GB | 250 GB | Fetch list per sesi (KB-an) → cukup untuk ribuan sesi/bln |
| MAU auth | 50.000 | 100.000 | Puluhan–ratusan |
| Edge fn | 500k invocations | 2 jt | `create-snap` hanya saat checkout (Fase 4) |
| Realtime | 200 koneksi, 2 jt msg | 500 / 5 jt | **Tidak dipakai** (app reload per pindah tab) |
| File storage | 1 GB | 100 GB | Tidak dipakai |
| Project | maks 2 aktif | bayar per project | 1 project |
| **Pause inaktif** | **ya, 7 hari** (diperketat 2026-02-01) | tidak pernah | **RISIKO UTAMA** |
| Backup otomatis | tidak ada | harian, simpan 7 hari | Manual CSV (D5) saja — lemah untuk data finansial |
| Log retention | 1 hari | 7 hari | `client_errors`/`audit_logs` = tabel kita (aman), tapi log platform cuma 1 hari |
| pg_cron | ✅ tersedia | ✅ | Untuk F3-d retention |

**Kesimpulan:**
1. **Free cukup untuk skala sekarang → Fase 4 aman dimulai di free.** Kuota utama semua >10× kebutuhan.
2. **Risiko #1 = pause 7 hari inaktif**: tanpa user buka app / API dipanggil selama seminggu, project berhenti → semua user error. Supabase kirim email peringatan ~1 minggu sebelumnya; pulihkan = 1 klik (backup disimpan max 1 tahun). Mitigasi: **D8 heartbeat cron**, baca email warning, atau Pro.
3. **Trigger naik Pro ($25/bln):** (a) DB > ~400 MB, (b) mulai ada revenue Midtrans → backup harian otomatis wajib untuk data finansial, (c) pause jadi berulang/panic, (d) butuh log platform >1 hari untuk debugging. **Disarankan: naik Pro bersamaan dengan launch Fase 4 publik**, bukan sebelumnya. Catatan: **Supabase TIDAK punya trial Pro** (docs billing 2026) — upgrade langsung kena tagihan, batal = prorated credit.

### Fase 3 — Test RLS server-side di CI (F3-c, 2026-09-25)

- **Harness:** `supabase/test/setup.sql` mereproduksi lingkungan Supabase di Postgres polos (role `anon`/`authenticated`/`service_role`, schema `auth` + `auth.uid()` dari GUC `test.user_id`, default privileges grant-all ke client roles).
- **Runner:** `supabase/test/run.sh` = reset skema → setup → `schema.sql` → `migration_02..12` (ON_ERROR_STOP) → `rls_test.sql`. `migration_13` dilewati (butuh pg_cron).
- **Workflow:** `.github/workflows/rls-test.yml` — push `supabase/**` + PR + manual; service `postgres:16`.
- **Cakupan assert (T01–T11):** regresi recursion migration_08; isolasi baca & tulis lintas org (wallets/tx/budgets/subscriptions/audit_logs/orgs/org_members); auto-join org korban ditolak; `mint_tx_code` non-member error; rate limit 10/60s + manual bebas; audit trigger `tx_auto_insert`/`org_join` + client write audit ditolak; `client_errors` per-user; invite (hash-only, admin-only read/create, join sukses, exhausted+rollback, idempoten, anon denied); `tx_sequences` tersembunyi; `wallet_balance` security_invoker.
- **Temuan → `migration_12_join_fixes.sql` (wajib jalankan):** [P0] A7 + [minor] A8 (lihat Sprint A).

### Fase E — Refactor struktur lanjutan: bedah `build()` sisa (**SELESAI**, 2026-09-25)

Lanjutan Fase A–D (struktur saja — **pixel identik, nominal lewat `amt()`, nol ubah business logic**).
Disetujui user di sesi sebelumnya ("lanjutin di sesi baru"); daftar target diverifikasi ulang dari kode terkini.

| # | Layar | Blok `build()` >50 baris (sebelum) | Status |
|---|-------|-------------------------------------|--------|
| 1 | `transaksi/transactions_screen` | `build@282=75` (state + ListView), `build@420=109` (`_TxFormCard`) | ✅ `6673fd6` — `_TxStateScaffold`/`_TxListBody`/`_TxFormCard` |
| 2 | `lainnya/notif_settings_screen` | `build@244=87`, `build@447=59`, `build@547=54` | ✅ `669b540` — `_StatusLines`/`_ServiceLine`/`_RecentList`/`_RecentChips` |
| 3 | `lainnya/billing_screen` | `build@77=83` | ✅ `0508afc` (+ fix analyze: ctor scaffold positional + `const loading`) |
| 4 | `laporan/reports_screen` | `build@127=74` | ✅ `1ad05f3` — `_ReportsScaffold`/`_TxListCard` |
| 5 | `auth/auth_screen` `build@197=65` · `dompet/wallets_screen` `build@159=64` | | ✅ `836d9ac` — `_AuthHeader`/`_AuthFields`/`_AuthMessages`/`_AuthActions` + `_WalletsScaffold`/`_WalletOverview` |
| 6 | `workspace/org_switcher` `build@149=61` · `auth/splash` `build@84=56` · `shell/main_shell` `build@102=53` · `auth/onboarding` `build@103=52` | | ✅ `066ef76`/`4685a66`/`e891590`/`21a46f1` — `_OrgSwitcherScaffold`/`_OrgPickerBody`/`_OrgListCard`, `_SplashLoading`/`_SplashError`, `_MainBottomBar._destinations`, `_OnboardingBody` (+ `_stepDots` pindah body) |

**Hasil:** semua `build()` layar <50 baris (yang tersisa >50 hanya 3 widget lama yang memang di-scope out).
CI batch akhir `36133546126` hijau (sha `21a46f1`) → APK `SSR-SPACE-2.3.9-22-fasee-bedah-build.apk`.
Catatan: run `36131718083` (notif_settings) sempat **merah** karena 2 temuan analyze → fixed `0508afc`.

**Cara kerja:**
- Ekstraksi jadi widget `StatelessWidget` named; section khusus layar → private class in-file; lintas layar → `lib/widgets/`.
- Nilai styling disalin **persis** (padding/color/font/radius tak boleh beda satu pun); nominal tetap lewat `amt()`.
- Verifikasi per langkah: `dart format` parse check lokal → commit per layar → push → CI hijau (batch 2–4 layar per push) sebelum lanjut.
- **Widget lama dilewati** (`pin_field` 72, `tx_row` 69, `bank_track_row` 54): widget kohesif hasil redesign `a0cf623`, panjang build wajar.
- File yang diubah: hanya file layar; tak ada SQL/test/service.

### Polish visual "Fintech Ledger" (2026-09-25, staged — belum commit)

Pass visual-only 8 layar, keputusan user: Fraunces dibundel (tanpa `google_fonts`), ilustrasi unDraw mirror + recolor zamrud, chart = donut, stage saja (CI setelah "commit").

- **P0 fondasi:** `phosphor_flutter ^2.1.0`, `flutter_svg ^2.3.0`, `lottie ^3.6.1`, `skeletonizer ^3.0.0`, `fl_chart` 0.66→`^1.2.0` (belum dipakai → bebas), sdk `>=3.11.0`; Fraunces variable TTF → `assets/fonts/` + family di pubspec; `assets/illustrations/` (6 SVG) + `assets/lottie/check_pop.json`. Sumber aset dikelompokkan di `/sdcard/Assets/SSR-SPACE-polish/`. Baru: `lib/theme/app_typography.dart` (`SsrType`: heroMoney/moneyLarge/moneyMedium Fraunces — hanya nominal tunggal besar; Fraunces tak punya `tnum`, daftar kolom tetap PJS), `lib/theme/app_icons.dart` (semantik → Phosphor duotone; render wajib `PhosphorIcon` agar lapis sekunder 20% tampil).
- **P1 ikon:** nav 5 + FAB, `category_icons.dart` (11 peta), `tx_row` (kategori + badge bolt→lightning + glif arah kecil Masuk/Keluar/Transfer), `wallet_row` per-tipe (cash→money, ewallet→deviceMobile, bank→bank), `NavTile`/bulan/mata/state/pelacakan/invite. Nol `Icons.` tersisa di scope (kecuali fallback error Lottie → diganti `AppIcons.success`).
- **P2 empty+sukses:** `EmptyView.illustration` (SVG 120px, copy UD identik) di 6 layar; invite-list teks polos → SectionCard + SVG; `success_lottie.dart` (`showSuccessFlash` overlay ~950ms, `errorBuilder` fallback) dipicu Simpan transaksi (tambah+ubah) & Simpan budget.
- **P3 chart:** Laporan `_MonthFlowChart`/`_DonutDial`/`_FlowLegend` (donut Masuk zamrud/Keluar bata, `%masuk` tengah, legenda `amt()` → mask-aware; touch mati; hanya bila arus >0) + Selisih → `SsrType.moneyLarge`; Budget `_BudgetGauge` (cincin fl_chart ganti `LinearProgressIndicator`, animasi via `duration`/`curve` — `swapAnimation*` deprecated di 1.2.0) + angka → `SsrType.moneyMedium`.
- **P4 permukaan+skeleton:** hero SURPLUS: shadow ink 18%/blur 24 + border putih 8% + orb sheen + angka → `SsrType.heroMoney` (logika badge tak berubah); radius: `state_views` 16→`SsrRadius.card` (bar 4px dibiarkan, pill track); `skeletons.dart` (7 rangka `Skeletonizer.zone`+`Bone`) ganti 7 `LoadingView` scope (splash/org_switcher/billing tetap spinner — out of scope).
- **Verifikasi lokal:** `dart format` bersih di 10 file sentuh; semua `build()` <50 (donut awal 75 → pecah `_DonutDial`); tiap nama ikon di-grep ke sumber paket; API `PieChartData`/`Skeletonizer.zone`/`Bone.uniRadius`/`Lottie.errorBuilder` dicek dari tarball pub.dev. `flutter analyze/test` hanya bisa di CI (tak ada Flutter arm64).
- **Pelajaran CI (4 run merah sebelum hijau):** `phosphor_flutter` 2.1.0 mati di stable baru → jangan andalkan paket ikon yang extend `IconData`; vendor TTF + tulis `DuoIcon`/`subOf` sendiri (codepoint stabil,/tests tetap jalan). Analyzer baru galak soal const (`non_const_argument_for_const_parameter` menolak variabel ke `IconData()`, `prefer/unnecessary_const`): pola aman = field `static const` + `const` hanya di call-site yang argumennya const semua.

---

## 5. Checklist verifikasi manual (device)

Setelah install APK v2.3.3+ & migration 07+08:

- [ ] Daftar / login → buat workspace → **Dompet load** (bukan “Gagal memuat dompet”)
- [ ] Tambah dompet “DANA” + “Bank”
- [ ] Lainnya → Pelacakan otomatis → izin listener → master ON
- [ ] Map DANA → dompet DANA, kategori kosong
- [ ] Trigger notif uji (atau notif bank asli) → recent “Tersimpan”
- [ ] Beranda: baris “Otomatis”, tanggal hari ini, nominal benar
- [ ] Notif identik hari berikutnya → bisa dicatat lagi (hash beda hari)
- [ ] Force save notif ambigu → masuk
- [ ] User kedua **tidak** bisa insert membership org pertama (cek via SQL / API)
- [ ] `mint_tx_code` org lain → error “not a member”
- [ ] Budget kategori belanja terisi bila set `track_cat_*`
- [ ] Jalankan `migration_09_wallet_balance.sql` di Supabase Dashboard
- [ ] Install APK `2.3.4+16` → Dompet: saldo tampil per baris; wallet baru = `Rp0`
- [ ] Tambah transaksi in 100.000 ke DANA → saldo DANA `Rp100.000`
- [ ] Tap baris → ubah wallet ke Bank → simpan → kode TX sama, saldo DANA/Bank berubah
- [ ] Transfer DANA→Bank 30.000 → DANA −30.000, Bank +30.000
- [ ] Hapus transaksi dengan konfirmasi → hilang dari list, saldo balik
- [ ] Form transaksi: dropdown menampilkan `nama · Rp…`
- [ ] Auto-track “dompet belum cocok” → tap → pilih dompet → simpan → baris “Otomatis” tetap, saldo benar
- [ ] User kedua: query `select * from wallet_balance` → hanya row org sendiri (atau kosong)
- [ ] Balances gagal load: Dompet tetap tampil nama, nominal “Belum termuat”, bukan 0
- [ ] Empty list Transaksi: teks ajakan catat, bukan layar kosong tanpa keterangan
- [ ] Tombol Hapus / Simpan / Batalkan edit: mudah ditekan satu tangan, tanpa overflow horizontal di layar kecil
- [ ] Tidak ada `—` (em dash) di copy UI hasil build
- [ ] Install APK `2.3.5+18` → splash → login → semua tab terbuka, FAB “Catat” muncul, nav bawah 5 tab warna zamrud saat aktif
- [ ] Onboarding PIN: dua field tak rebutan fokus (field kedua fokus saat diketuk)
- [ ] Catat transaksi manual (in/out/transfer) dari FAB → tersimpan, saldo berubah
- [ ] Reproduksi **bug sisa** yang dilaporkan user → catat gejala + screenshot di sesi baru (A0)
- [ ] Jalankan migration_10_org_invites.sql di Supabase Dashboard
- [ ] Lainnya → Undang anggota → Buat undangan → salin kode → org switcher (device/user kedua) → Gabung → masuk workspace
- [ ] Kode invite kedaluwarsa/dipakai → pesan spesifik, bukan error generik
- [ ] Master ON → notif persist "SSR SPACE aktif" muncul; swipe app dari recents → buka lagi → transaksi notif tercatat
- [ ] Master OFF / logout → notif persist hilang
- [ ] Jalankan `migration_11_hardening.sql` di Supabase Dashboard (setelah migration_10)
- [ ] Auto-track normal (1–2 notif) → "Tersimpan" + baris `tx_auto_insert` muncul di `audit_logs`
- [ ] User join workspace (manual & via invite) → row `org_join` di `audit_logs`
- [ ] `insert into audit_logs` dari client biasa → ditolak RLS; `select` hanya row org sendiri
- [ ] Flood ≥11 notif cepat → status "Dibatasi, terlalu banyak. Coba lagi."; setelah >60 detik auto-track bisa lagi
- [ ] `client_errors` terisi setelah error uji → cek di Dashboard: ada `app_version`, **tidak ada** nominal/note/isi notif di kolom mana pun
- [ ] Install APK `2.3.7+20` → Lainnya → Cadangkan data → share sheet berisi 3 CSV; buka di Sheets → kolom lengkap, angka benar
- [x] Push Fase 3 → CI hijau walau semua action di-pin SHA; Dependabot sudah aktif (2 PR update github-actions sukses)
- [x] Push F3-c → run `rls-test` hijau (`36107004906`, suite T01–T11 lulus di postgres:16 CI); `build-apk` `36107004899` hijau
- [x] Jalankan `migration_12_join_fixes.sql` di Supabase Dashboard (setelah migration_11) — ✅ user 2026-09-25
- [ ] **Buat workspace BARU** → berhasil (bukan "Gagal membuat workspace") — regresi P0 A7
- [ ] Join via invite → keluar → tempel kode sama lagi → sukses/idempoten (bukan error "sudah dipakai")
- [x] Jalankan `migration_13_retention.sql` → ✅ user 2026-09-25 (cek `select * from cron.job where jobname like 'ssr_%'` → 3 job ada)
- [x] Secret `SUPABASE_DB_URL` diset (session pooler URI) → `backup-db` run `36110689118` hijau, artifact `ssr-space-backup` 63 KB `.dump`
- [x] Tanpa secret: `backup-db` skip dengan warning, tidak merah (run `36108091344`)
- [ ] Notif **SeaBank** asli → status recent "…dari SeaBank", pref `track_wallet_SeaBank` (bukan KEB Hana)
- [ ] Notif **MyHana/KEB Hana** → label "KEB Hana" (bila app terpasang)
- [ ] Toggle samarkan nominal (mata di Beranda / tile Lainnya) → beranda, transaksi, dompet, budget, laporan, recent jadi `Rp ••••••`; mati lagi → normal; **restart app → state tetap**; harga plan Billing tidak ikut disembunyikan
- [ ] Install APK `2.3.9+22` → splash menampilkan tagline baru (2 baris, center)
- [ ] User lama buka app → carousel intro muncul 4 halaman, swipe/`Lanjut` jalan, dots sinkron
- [ ] Halaman 4: tombol "Setuju & mulai" **mati** sebelum dicentang; centang → aktif → setuju → lanjut ke workspace/PIN
- [ ] Force-kill app sebelum setuju → buka lagi → carousel muncul lagi (flag belum tersimpan)
- [ ] Setuju sekali → restart app → carousel **tidak** muncul lagi
- [ ] Visual font: seluruh layar pakai Plus Jakarta Sans; wordmark "SSR SPACE" (splash/auth) pakai Anton; **angka rupiah tetap sejajar (tabular)** dan tak ada overflow/terpotong di layar kecil
- [ ] Carousel intro: ikon Phosphor Fill tampil (bukan kotak/huruf aneh); tombol/checkbox mudah ditekan
- [ ] Install APK `2.3.9-22-fasee` → buka layar Transaksi, Pelacakan otomatis, Billing, Laporan, Masuk, Dompet, Pilih workspace, Splash, Beranda (nav bawah + FAB), Onboarding PIN → **tampilan identik** dengan APK `2.3.9-22-refactor` (Fase E struktur-saja)
- [ ] Install APK polish → Beranda: angka SURPLUS pakai serif Fraunces, kartu gelap ber-shadow; nav bawah + ikon kategori/dompet = Phosphor duotone
- [ ] Simpan transaksi & Simpan budget → kilatan centang ~1 detik, lalu snackbar seperti biasa
- [ ] Laporan: donut Masuk/Keluar + `%masuk` tengah + legenda; mask ON → angka legenda jadi `Rp ••••••`, persen tetap
- [ ] Budget: tiap kartu ada cincin gauge (bata bila lebih batas); angka `spent dari limit` serif
- [ ] Matikan internet lalu buka tiap layar → skeleton meniru bentuk konten (bukan spinner); font Fraunces tetap tampil (offline)
- [ ] Layar kosong (bulan tanpa transaksi/budget/dompet/undangan) → ilustrasi zamrud + copy lama + CTA jalan
- [ ] Install APK iris4 → Profil: 9 seksi tampil, tiap baris dibuka (layar nyata atau dialog P2), nol dead tap
- [ ] Pengaturan: ganti bahasa ID/EN → seluruh copy ikut; ganti kurs → angka ikut; font 0.85 dan 1.3 → tidak overflow
- [ ] Cari pengaturan: ketik "dompet"/"wallet" → hasil tepat; kata asing → pesan "Tidak ada pengaturan yang cocok. Coba kata lain."
- [ ] Impor CSV: tempel teks → pratinjau mapping benar → impor → transaksi masuk dompet yang dipilih
- [ ] Pengingat harian: set jam → notifikasi muncul esok hari di jam itu; reboot HP → jadwal tetap jalan
- [ ] Auto-track + overlay koreksi tetap jalan seperti sebelumnya (regresi iris3/iris4)
- [ ] Tentang → versi `2.3.9+22`; Catatan perubahan → isi changelog tampil
- [ ] Loop audit impeccable 2.8.0+56 s/d +58 (device, APK yang bisa diunduh): font app 1.3 + font HP Besar → Transaksi/Laporan/Dompet/Budget/Beranda/sheet input tanpa overflow atau terpotong
- [ ] Mode gelap HP → semua layar terbaca; teks di atas rust hanya di surface terang
- [ ] Putar landscape tiap layar utama → scroll jalan, nol clip; PIN + sheet catat tetap bisa dipakai
- [ ] Split-screen (bila HP dukung) → setengah layar tanpa overflow horizontal
- [ ] TalkBack ON → tombol ikon bernama (Hapus/Tutup/Kembali), tombol hapus numpad terbaca "Hapus", baris Tx terbaca jenis + nominal
- [ ] Bulan dengan >50 transaksi → scroll mulus, header hari + divider tampil benar (slivers 2.8.0+57)
- [ ] Badge kategori tampil Coolicons seragam; olahraga/hewan/darurat tetap ledger (distill 2.8.0+58)

---

## 6. Test yang menutup temuan

| File | Menutup |
|------|---------|
| `test/notif_parse_test.dart` | nominal, classify, **hash beda hari**, **allowlist exact**, ymd |
| `test/notif_track_test.dart` | dayLabel, txTime, CapturedNotif, pref key clash |
| `test/session_service_test.dart` | PIN, lockout, first-run |
| `test/dashboard_calc_test.dart` | total in/out |
| `test/budget_progress_test.dart` | progress cap |
| `test/month_category_test.dart` | helper bulan + icon fallback |
| `test/org_select_test.dart` | persist org |
| `test/wallet_model_test.dart` | fromMap |
| `test/tx_payload_test.dart` | `date` null → default hari ini (bukan null), `now` injectable |
| `test/tx_validation_test.dart` | `validateTxInput` |
| `test/wallet_balance_test.dart` | kalkulasi saldo `wallet_balance` |
| `test/error_reporter_test.dart` | dedupe 60 menit, cap 20/jam + reset, payload persis 4 kunci + clip 500/4000 (tanpa PII) |
| `test/backup_export_test.dart` | header + escaping CSV 3 tabel, nama file, baris kosong |
| `test/notif_track_test.dart` (tambahan) | `saveErrorStatus`: RATE_LIMITED → "Dibatasi…", 23505 → "Sudah pernah dicatat", lainnya → "Gagal simpan: code" |
| `supabase/test/rls_test.sql` (CI, bukan Flutter) | **40+ assert RLS**: regresi recursion, isolasi lintas org, join korban, mint_tx_code, rate limit, audit log, client_errors, invite hash/idempoten/exhausted/anon, tx_sequences, wallet_balance |
| `test/mask_test.dart` | `amt()` asli/menyamar, default OFF saat prefs kosong, persist `mask_amounts` |

**Belum ada test:** pipeline `_onEvent` penuh (mock Supabase).

---

## 7. Changelog audit → release

| Commit | Isi |
|--------|-----|
| `9634116` | P0 RLS+mint + P1 auto-track (wallet/date/allowlist/hash/insert-order) + tests + v2.3.3+15 |
| `1c401ef` | Fix prefix KEB Hana `id.co.bankbkemobile` (CI test merah) |
| `d4aec58` | **migration_08** fix RLS recursion “Gagal memuat dompet” |
| `bfc2017`…`d8d5953` | wallet_balance + edit/delete tx + validateTxInput + v2.3.4+16 |
| `30787f2`…`776b764` | auto-track: parser IDR, classifier fleksibel, deteksi service disconnect, postTime |
| `385489a` | **Fix input manual gagal**: `txInsertPayload` + test + error transparan + v2.3.4+17 |
| `a0cf623` | **Redesign UI/UX** anti-slop ENERGY 2 / RHYTHM 2 / MOTION 2, 16 layar + 5 widget, hapus dashboard + v2.3.5+18 |
| `4693c88` | Fix build APK: `FloatingActionButton.extended` + `NavigationBarTheme.iconTheme` |
| `2e849c6`…`0c8132b` | **Fase 1 scale**: invite workspace (migration_10, token hash, RPC `join_org_by_invite`, layar Undang anggota) + foreground service `specialUse` (`ForegroundTrack`, wiring lifecycle, CI inject Manifest) + v2.3.6+19 |
| `83f10b4` | migration_10 hardening: gerbang `used_count` atomik (`INVITE_EXHAUSTED` + rollback), hash invite di-`upper()` sinkron dgn client, revoke execute dari `public`/`anon` |
| `4642d52` | Invite UI: guard tombol utk non-admin, map RLS `42501` ke pesan jelas (bukan error generik) |
| `b2703ad` | Foreground: telan error stop service saat logout; fix fakta di AGENTS/AUDIT. CI run `36086384993` hijau |
| `3658b2c` | Docs: changelog 3 commit hardening + aturan wajib catat hasil kerja di AGENTS/AUDIT |
| `739fbb4` | **Fase 2 D1**: langkah `flutter analyze` blocking di CI sebelum test |
| `e7e88e8` | Bersihkan **26 temuan analyze**: await di splash `_boot`, curly braces, `withValues`, `initialValue` dropdown, `publishableKey`, hapus import sisa, `const pw.TextStyle`. Run `36090886163` hijau (analyze+test+APK) |
| `74d85c5` | **migration_11**: trigger rate limit auto-insert (10/60s/org) + `audit_logs` (trigger `tx_auto_insert`/`org_join`, RLS deny client write) + `client_errors` |
| `dbc7794` | **ErrorReporter** in-house: dedupe/cap murni Dart + payload tanpa PII + `AppInfo.version` + test |
| `391d747` | Mapping `RATE_LIMITED` → status "Dibatasi, terlalu banyak. Coba lagi." (`saveErrorStatus`); wiring `ErrorReporter` ke `main` (init + `runZonedGuarded`) & catch pipeline notif + test |
| `105beaf` | **D5 backup**: `backup_export.dart` (3 CSV builder) + tile Lainnya → Cadangkan data + test |
| `0ba570b` | Fix temuan analyze pertama: `LineSplitter` static, hapus `dart:ui`, `const` test. Run `36098447278` hijau penuh → APK `2.3.7+20` |
| `12d1a26` | Spec + implementation plan Fase 2 hardening |
| (Fase 3) | **D4 supply chain**: `.github/dependabot.yml` + pin 4 action ke commit SHA di `apk.yml`; D2 sekalian (checkout v7.0.1, setup-java v6.0.1, flutter-action v2.23.0, upload-artifact v7.0.1). Spike limit plan Supabase → §4 |
| (Fase 3 F3-c/d) | **Test RLS CI**: `rls-test.yml` + `supabase/test/{setup,run,rls_test}` (40+ assert) → temukan **[P0] bikin workspace gagal sejak 07** + [minor] re-join invite EXHAUSTED → `migration_12_join_fixes.sql`; **retention**: `migration_13_retention.sql` (pg_cron 3 job) + `backup-db.yml` pg_dump mingguan |
| (A0) | **Fix allowlist SeaBank/KEB Hana** + **fitur privacy mode "Samarkan nominal"**: `notif_parse.dart` (SeaBank ← prefix BKE, KEB Hana ← `co.id.myhana.app`), `mask.dart`/`amt()`/`MaskToggle`, `MainShell` rebuild global, 7 layar + `tx_row`, tile Lainnya, `test/mask_test.dart`, docs |
| (tagline+consent) | **Tagline resmi "Simple. Secure. Reliable. Your Finance Space."** + **IntroConsentScreen** carousel 4 halaman (brand → nilai → kesadaran finansial → syarat + checkbox, prefs `consent_v1`, gate splash) + **font global** PJS/Anton/Phosphor-Fill (`assets/fonts/`, `SsrFonts`) + pubspec D3 ditutup + v2.3.9+22 |
| `112c64d` | **Refactor Fase A (struktur only)**: `lib/core/{saas,session,format,theme}` → `lib/{services,utils,theme}` + `lib/screens/<fitur>/` (auth, shell, beranda, transaksi, dompet, budget, laporan, lainnya, workspace); import saja, nol ubah kode. CI run `36123125093` hijau |
| `19e979d` | **Refactor Fase B**: widget baru `NavTile`, `WalletRow`, `BankTrackRow`, `LabeledSectionCard`, `TxTypeSelector` (re-use 5 widget lama), dekomposisi `build()` besar per layar, dedup `_orgId`→`lib/utils/org_prefs.dart`. CI run `36125021068` **merah** (2 error analyze) → fix menyusul |
| (fix Fase B + docs) | Fix 2 error analyze: `nav_tile` `Text(String?)` → promosi lokal; `RecentNotifTile._saveButton/_pickTypeAndSave` bawa `BuildContext` eksplisit (StatelessWidget tak punya `context` di luar `build`). **Fase D docs pass**: path basi `lib/core/…` di AGENTS/AUDIT diganti struktur baru + tree §5 ditulis ulang + catatan spec historis pakai path lama. CI run `36126303610` hijau penuh → APK `SSR-SPACE-2.3.9-22-refactor.apk` |
| `2322201`…`10ff697` | **Fase E sesi 1**: rencana ditulis ke AUDIT + bedah `transactions` (`6673fd6`), `notif_settings` (`669b540`), `billing` (`0508afc` fix 2 temuan analyze: ctor scaffold positional + `const loading`), `10ff697` buang HANDOFF.md dari repo. Run `36131718083` merah → fix → `36132306668`+`36132388087` hijau |
| `1ad05f3`…`21a46f1` | **Fase E sesi 2 — SELESAI**: `reports` (`1ad05f3`), `auth`+`wallets` (`836d9ac`), `org_switcher` (`066ef76`), `splash` (`4685a66`), `main_shell` (`e891590`), `onboarding` (`21a46f1`). Semua `build()` layar <50 baris (sisa 3 widget lama di-scope out). CI `36133546126` hijau → APK `SSR-SPACE-2.3.9-22-fasee-bedah-build.apk` |
| (staged 2026-09-25) | **Polish "Fintech Ledger" P0–P4** (visual-only, belum commit): deps + Fraunces + `app_typography`/`app_icons`; re-skin Phosphor duotone; EmptyView ilustrasi + `success_lottie`; donut Laporan + gauge Budget; hero texture + `skeletons` (7 loading). Detail: §4 "Polish visual". CI (analyze/test/APK) jalan setelah user bilang "commit" |
| `b89d797`…`80fce1f` | **Polish hijau** (run `36148631602`): analyze 0 issue, **60 test lulus**, APK `SSR-SPACE-2.3.9-22-polish-ledger.apk`. Perjalanan: `prefer_const_constructors` (`341314b`) → **`phosphor_flutter 2.1.0` pecah di stable kini** (`IconData` final, `month_category_test` gagal load) → **vendor `Phosphor-Duotone.ttf`** + `DuoIcon`/`subOf` sendiri, lepas dep (`2f576de`); lalu 3 run merah karena aturan const baru (`non_const_argument_for_const_parameter` menolak argumen variabel ke `IconData()`, `prefer/unnecessary_const`): `subOf` → switch literal (`e2dfcc9`+`5ab591e`), field `static const` + `const DuoIcon` di call-site const (`ee74654`+`46ee097`); test `month_category_test` → harapkan `AppIcons` (`80fce1f`) |
| `f14bd10`…`ecb5850` | **Template PDF premium + kuota plan** (run `36153839333` hijau, **62 test**): `report_pdf.dart` (kop aksen + ringkasan 3 kotak + tabel zebra + rekap 8 kategori top + footer halaman, font PJS dibundel, fallback Helvetica) + `test/report_pdf_test.dart` (2 assert `%PDF`); `plan_limits.dart` (Gratis: workspace 2, anggota 3, auto 150/bln, CSV saja — diputuskan user 2026-09-25); `activeOrgName()`; `_exportPdf` lama (teks polos) dibuang. 3 run merah: `unnecessary_import` typed_data + `prefer_const` pw (fix) → `invalid_constant`/`const_with_non_const` (const hanya argumen literal) → `TableBorder.all` kontradiksi (prefer vs bukan const ctor → `// ignore` 1 baris). APK `SSR-SPACE-2.3.9-22-pdf-premium.apk` |
| `89080a1` | **Tegak kuota di 4 titik** (run `36155923567` hijau, **67 test**): buat workspace (`org_switcher`, hitung `orgs.length` + plan aktif), undang anggota (`invite`, `memberCount` + plan org), export PDF (`reports` `_guardPdf`), auto-track (`notif_track_service` gate: plan + `autoUsedThisMonth`, fail-open bila query gagal; `forceSave` manual dikecualikan). Blokir → `requirePro` (snackbar + ke Billing). `test/plan_limits_test.dart` (5 assert batas). APK `SSR-SPACE-2.3.9-22-kuota-gratis.apk` |
| `61c2f55` | **Fix ISAKU + PIN dari SS user** (run `36181290216` hijau, **69 test**): (1) nominal null — regex greedy menelan titik akhir kalimat (`Rp. 17.000. Ref` → grup `17.000.` → tryParse gagal) → grup wajib berakhir digit; (2) jenis null — `cash in`/`isi ulang` tak dikenal → tambah ke `_inKeys` (aturan dua-arah tetap jaga); (3) PIN tak mengisi saat ketik — listener controller tanpa `setState` → rebuild tiap ketik + highlight fokus, kotak `Expanded` anti-overflow + `HitTestBehavior.opaque`. APK `SSR-SPACE-2.3.9-22-fix-isaku-pin.apk` |
| `3e089b6` | **F1 riwayat per dompet** (run `36186962893` hijau, 69 test): `WalletDetailScreen` (kop saldo + hitung transaksi + list `TxRow`, empty ilustrasi) dibuka dari ketuk `WalletRow` (InkWell bila `onTap` ada); query baru `TransactionService.listByWallet` (`wallet_id`/`to_wallet_id`, limit 200). APK `SSR-SPACE-2.3.9-22-riwayat-dompet.apk` |
| `43feacc` | **F2 kelompok laporan + F3 PIN budget + F4 settings ID/EN** (i18n penuh `strings.dart`/`tr()`, kurs, font, OTP): run `36194242303` **merah** — `tr()` di dalam `const` + import `fl_chart` terbuang + `_historyTitle` tak terlihat dari StatelessWidget |
| `207f512`+`8127fcf` | **Follow-up i18n** (run `36203932158` merah → `36204433528` merah → hijau di bawah): drop `const` induk di 8 file (`const` tetap di argumen murni), kembalikan `fl_chart`, buang `unused_import` foundation, `_historyTitle` → top-level `txHistoryTitle()`. Pelajaran: analyze fatal bahkan untuk info (`prefer_const_constructors` 1 baris). `HANDOFF.md` sempat ke-commit (`207f512`) lalu dibuang dari repo |
| `833cc49` | **Fix `transfer_detect`** (run `36204732391` hijau, **79 test**): greedy out-terawal klaim `in` bersama (T3 gagal `o1` vs `o2`) → kandidat global dipasangkan dari gap terkecil (`_Candidate`, `usedOut`+`usedIn`); diverifikasi lokal `dart` murni 4/4 PASS. APK `SSR-SPACE-2.3.9-22-i18n-fix.apk` |
| `84bee1b`+`553e9fd` | **Waktu detail di TxRow** (run `36210627031` hijau, **83 test**): `txWhenLabel()` (`datetime.dart`, "26 Sep 2026 • 12:04" / tanggal saja / sembunyi) + baris `bodySmall` secondary tabular di bawah chips → berlaku di Transaksi, Laporan, Riwayat Dompet sekaligus. `test/datetime_test.dart` (4 assert, TZ-aman). Verifikasi lokal `dart`+stub `tr()` 7/7 PASS. APK `SSR-SPACE-2.3.9-22-txrow-waktu.apk` |
| `0506288` | **Kategori global (batch 1/3 koreksi instan)** (run `36215350735` hijau, **87 test**): `app_categories.dart` (10 default disepakati user, sanitize murni, prefs + notifier, load di main) + `CategoriesScreen` (tambah/hapus/simpan/reset, cegah duplikat & <1) di kartu Data; `test/app_categories_test.dart` (4 assert, diverifikasi lokal `dart`+stub 5/5) |
| `0766aac` | **Chip saran kategori (batch 2/3)** (run `36215967833` hijau): `CategoryChips` baru dipakai ulang di form transaksi + budget (ketuk → isi field, ketik bebas tetap bisa) |
| `766c063`+`5f0c9a8` | **Koreksi instan (batch 3/3)** (run `36217156334` hijau, **90 test**): overlay 30 dtk (`flutter_overlay_window` 0.5.0, `overlayMain`, shareData JSON, auto-tutup; izin+service diinject CI) + sematan teks notif foreground 3 mnt + sheet koreksi (chip+catatan, Simpan/Lewati → `update()`, pending prefs, buka saat resume) + toggle/izin di notif_settings + `getById` + `test/instant_correct_test.dart` (3 assert). Sengaja tanpa `flutter_local_notifications` (hindari desugar/AGP). APK `SSR-SPACE-2.3.9-22-koreksi-instan.apk` |
| `ff8d84d` | **Audit allowlist vs package resmi** (run `36223671362` hijau, 90 test): dari SS user — `com.shopeepay.id` tak cocok prefix `com.shopee` → auto gagal + save manual yatim tanpa dompet (saldo diam, saldo ISAKU wajar kosong karena ISAKU tak kirim notif). Cek `pm list packages` di HP + Play Store → tambah `com.shopeepay`, `ovo.id`, `com.gojek.gopay`, `com.bca`, `src.com.bni`, `com.jago.digitalBanking`, `com.bcadigital.blu`, `id.co.cimbniaga`; `matches()` jadi case-insensitive (gagal tangkap `com.jago.digitalBanking`). Jenius/Livin/BTN/BRI terbukti sudah cocok. Diverifikasi lokal `dart` 19/19 PASS. Perbaikan data TX-000025 (isi dompet SHOPEE PAY) + OUT ISAKU manual bisa user lakukan di app (transfer_detect pasangkan badge) |
| `852aa22` | **Peringatan tanpa-dompet (opsi C, lanjutan ff8d84d)** (run `36226716859` hijau, **95 test**): akar selisih Home vs Dompet = metrik beda + transaksi null-wallet (masuk Home, tak masuk `wallet_balance`): `tx_wallet_check.dart` (`hasNoWallet`/`noWalletTotal`, in/out vs transfer dua-sisi) + `test/tx_wallet_check_test.dart` (5 assert, lokal `dart` 10/10 PASS); chip danger `tx_nowallet` di `TxRow` (semua layar); banner dangerSoft di riwayat Transaksi (`{n} tanpa dompet · {a} tak masuk total aset` + filter Hanya tanpa dompet/Tampilkan semua, reset saat ganti bulan); guard `_onEvent`: wallet null → tahan insert, status `st_need_wallet` (petakan di Pelacakan otomatis → Simpan manual; `forceSave` tetap boleh sadar-tanpa-dompet). Form manual memang sudah wajib dompet (`tx_validation.dart:10`) — tak diubah |
| `cbedeeb` | **SeaBank `melakukan transfer` + Tes overlay** (run `36228406358` hijau, **96 test**): allowlist SeaBank BENAR (label cocok — bukan pengulangan A0); akar = classifier tak kenal wording SeaBank "Kamu baru melakukan transfer real-time senilai Rp17.000…" (amount lolos, type null → `st_unread`; scan 14:34 lihat konten kosong = notif SeaBank terbit bertahap). Fix: out-key `melakukan transfer` + test teks asli (`notif_parse_test.dart`, lokal `dart` 3/3 + regresi 7/7: menerima-transfer tetap in, ambigu tetap null). Overlay: toggle ON + izin aktif + service hidup (SS 14:49) → tersangka = insert via Simpan manual (`forceSave` tak panggil `offer()`) ATAU MIUI blokir background-overlay diam-diam; alat diagnosis = tombol **Tes overlay** di kartu Koreksi instan (`InstantCorrect.testOverlay()`, tanpa DB/pending, auto-tutup 30 dtk, ketuk Lengkapi aman karena pending null) |
| `b87f0a4` | **BigText fallback (akar SeaBank unreadable)** (run `36231549517` hijau, **96 test**, patch CI terkonfirmasi di log): live `handleNotification` + scan `getActiveNotificationData` hanya baca `EXTRA_TITLE`/`EXTRA_TEXT`, tak pernah `EXTRA_BIG_TEXT`; SeaBank taruh detail di BigText saja → content null): `pubspec` pin exact `1.0.0` + step python di `apk.yml` (fallback di 2 titik, assert keras: drift = CI merah). Tanpa ubah Dart; parser `melakukan transfer` dari commit sebelumnya langsung pakai. Verifikasi akhir di device user (pindai ulang → isi + Simpan) |
| `a7b7c76` | **Optimasi CI** (run `36234211595` hijau; run populate-cache ini ~14 mnt — hemat terasa dari run berikut): bedah: build apk 10m21s/85% + setup Flutter 1m, tanpa cache apa pun): `cache: true` di flutter-action + `actions/cache` pub (`pubspec.yaml` hash, tanpa lock di repo) + `gradle/actions/setup-gradle` (semua pin SHA, ikut D4) + `paths-ignore` `**.md`/`docs/**` (commit murni-docs skip CI). Run pertama populate cache, hemat terasa dari run kedua |
| `ed3ffc3`+`eb42243` | **Auto-gabung transfer** (minta user, scope auto+auto ke depan; histori tak diubah): pasangan out+in nominal sama dompet beda ≤10 mnt yang keduanya Otomatis langsung jadi 1 baris `transfer` — `pickAutoMerge()` murni di `transfer_detect.dart` + test (2 assert baru, lokal `dart` 6/6) + hook `_tryAutoMerge()` di `_onEvent` (fail-open: ragu/gagal → dua baris + badge; `listSince()` 30 mnt di `transaction_service.dart`; kode TX milik OUT, kode IN hangus; note + `nt_automerge`); offer koreksi jalan di baris surviving (`summary()` kenal `transfer` + test). Efek: Income & Expense Home turun masing-masing nominalnya (net tetap), saldo dompet net tetap. CI: run `36235373116` merah → root cause = script patch BigText lama tak idempoten + pub-cache menyimpan hasil patch (run `36234211595` simpan cache SUDAH-patch; run berikutnya `b_old` count 0). Fix `eb42243`: patch diagnostik + regex toleran + skip bila sudah-patch; run `36236111761` hijau (**98 test**) |
| `aad786f`+2 fix | **Ganti PIN via magic-link deep-link** (run `36239560846` hijau, **102 test**; sempat merah 2x: YAML `'''` kolom-0 + `unused_field _sub`): `_PinCard` kirim `signInWithOtp(emailRedirectTo pinLinkCallback, shouldCreateUser false)` → ketuk link → `app_links` (`uriLinkStream`, init di `main`) → `pin_link_verify.dart` parse `token_hash` (murni `auth_link_parse.dart` + test, lokal `dart` 4/4 RED→GREEN) → `verifyOTP(tokenHash, magiclink)` → form PIN baru. Fail-closed (hanya type magiclink). Dep baru `app_links ^7.2.1`; intent-filter CI; user tambah redirect URL di Dashboard (tanpa SQL) |
| `9bd4411`..`f170df3` | **Workspace premium** (spec+plan SDD, subagent-per-task + review): `migration_14` RPC list/kick/delete (SECURITY DEFINER, anti-rekursi) + assert T12-T15 (suite lokal SUKSES 41 assert; CI rls-test hijau); `workspace_service`, `pin_dialog` bersama, `WorkspaceDetailScreen` (hero gelap, ledger anggota, danger ketik-nama+PIN); review temukan 2: T15-spasi (refutasi byte-persis, suite memang hijau) + invite-workspace-salah (fix: gate ke active view). Run apk hijau 102 test. User wajib jalankan `migration_14` manual |
| `686316b`+`cfb0d54` | **Input transaksi premium** (run `36251716559` hijau, **123 test**): riwayat saja + `TxInputSheet` (tombol + tengah `centerFloat`, numpad custom, tanggal wajib + jam opsional → `date`+`created_at`, tanpa migration) + `tx_input_logic.dart` murni (lokal 30/30) + `test/tx_input_test.dart` (21 case). 3 subagents paralel; CI merah 1x (`)` numpad + doc-comment info) → fix. APK `SSR-SPACE-2.3.9-22-tx-premium.apk` |
| `5af4d82`+`2b2e920` | **Tabungan premium** (run `36254042802` hijau, **127 test**): konvensi kategori tanpa migration (`saving.dart` murni 14/14 lokal + `test/saving_test.dart`); kartu target emas + `savings.svg`; banner limit>pemasukan; hapus budget + PIN; donut 3 iris; strip rincian dompet + filter. 2 subagents layar + review (clamp→num, const, dead API); merah 1x (`const_with_non_const` BorderRadius) → revert. APK `SSR-SPACE-2.3.9-22-tabungan-premium.apk` |
| `d2c75d6` | **Fix blank hitam (hapus budget) + abu (ganti workspace)** (run `36273729676` hijau, 127 test): vonis dari `client_errors` — No element (`pop→pop→_submitPin`) = `onCompleted` PIN multi-fire → guard `_fired` di `pin_field.dart`; Stream already listened = `overlayListener` double-listen saat `pushReplacement` → `overlay_bus.dart` + migrasi `main_shell`; `AppInfo.version` → 2.3.9+22. APK `SSR-SPACE-2.3.9-22-fix-blank-hitam-abu.apk` |
| (iris1-iris4) | **Profil + settings ramping + diet APK** (SDD 10 task): iris1 prefs/strings/hub/settings (run `36277436482` hijau, APK 65M = baseline); iris2 impor CSV (run `36278791306` hijau, 65M); iris3 reminder+search (run `36281671805` hijau, 67M, +2M dep notif); iris4 split per-ABI + size-report + minify (run `36282567001` hijau: universal 67M file, arm64 24.4M, armeabi 22.6M, x86_64 25.9M; native libflutter 11.7M + libapp 10.8M, dex 8.6M kena backport desugar) |
| (iris5) | **Diet audit + penutup settings** (digabung push penutup): lepas `sqflite` + `path` dari pubspec (grep bukti nol import di lib/ dan test/; `path_provider` dipakai 2 layar jadi tetap); seluruh SVG/lottie/font/changelog terbukti dipakai (nol hapus file); filter `grep -E` size-report; tooltip jam pengingat; guard `_ListStyleCard`; koma ganti en-dash komentar; `close()` delegate search + kunci `search_no_result`; try/catch `_load` changelog; 7 one-pager P2 `docs/superpowers/specs/2026-09-26-p2-*.md` (semua tanpa migration) |
| (fix wave) | **Review final honesty + dedup** (digabung push penutup): subtitle `msg_p2` di 5 kartu settings; `imp_pick` Tempel/Paste CSV; About nyata (share app + feedback via share sheet, dialog help/privacy/about, 2 kunci baru `ab_help_body`/`ab_privacy_body`); `parseHeaderNames` + `resolveToWalletId` murni (layar + tile satu helper, 4 expects baru); `InstantCorrect.clearMemory()` di settings + hub; main pakai notifier reminder; validasi setter + fallback load; `_load` langsung; o_mask tetap hub-close (catat alasan di laporan task-10) |
| (batch P2, run `36289760838` hijau) | **7 P2 tanpa migration** (logika murni diverifikasi lokal via mirror: P2-1 7/7, P2-2 6/6, P2-3 6/6, P2-4 7/7, P2-5 4/4, P2-7 5/5; YAML CI valid + py inject compile OK; flutter analyze/test = CI): reminder-copy (body dinamis per tanggal, 6 test) + calm-streak (8 dot, 5 test) + reports-topn (Top-8+Others, reorder persist, 5 test) + recurring-bills (prefs JSON cap-30, saran Beranda, prefill sheet, 6 test) + subcategory (`A > B`, meta warna/ikon, 4 test) + wallet-svg (3 redrawn + `WalletArt`, 2 test) + widget-QS (snapshot prefs + provider/tile inject `apk.yml`, 4 test). 7 file test baru (±36 expects). CI sempat merah 1x (error: field `billsDue` menutupi fungsi `dueBills()` + 3 info: `initialValue` dropdown, `const` TextStyle, `onReorderItem`) → fix `8a5b8bf`, hijau penuh. Batas sadar: widget ikut `onUpdate` sistem; fallback native ID; koreksi instan tak kenal sub |
| (paket R, belum push) | **4 fitur referensi Ollo tanpa migration** (SDD 8 task: 4 logika + 4 UI, tiap task review CLEAN; logika diverifikasi lokal via `dart`, analyze/test penuh via CI): R1 grup per-hari (`tx_day_group.dart` 5 test + `DayHeader` di 3 layar); R2 filter per-dompet session-only di Laporan (4 test, export tetap sebulan penuh); R3 Most-used (prefs `wallet_use_count`, 5 test, hook manual/koreksi; stale diabaikan); R4 komposisi aset (5 test + strip Dompet + tipe `savings`/`investment` client-only). Fix round: sort-test ekspektasi ids + eviksi insertion-index (sort Dart tak stabil, asumsi stabil terbantah). Version `2.4.0+23` |
| (new design, belum push) | **Rombak visual Emerald Noir full-app** (SDD 11 task, tiap task review CLEAN; kontras AA terukur per task, analyze/test penuh via CI): token noir 9 warna + `SsrTheme.noir()` + DESIGN.md dial 2/2/1; Duotone penuh 22 situs; auth, beranda, transaksi, dompet, budget, laporan (legenda anti-potong), lainnya + settings + workspace (P2-noise jadi satu baris per seksi), sheet + nav + StatusChip; segmented mint-filled via `ssrSegmentedStyle()`. Visual-only tanpa migration/dep/logic berubah. Fix round: 4 segmented + token noirBg. Version `2.4.1+24` |
| Ledger Premium (run `36313239571` hijau, 212 test) | **Ganti noir → Ledger Premium** (SDD 8 task + fix waves, otoritas prompt + HTML user; noir SUPERSEDED): T1 token `AppColors` 14 hex exact + `AppTheme.light()/dark()` + wiring `main` system + kontras 9/9 AA+; T2 12 SVG kategori (`svgForCategory`, TxRow wadah goldSoft/rust-tint + subtitle `·` + prefix U+2212); T3 radius 24/12/999 + SectionCard/StatusChip/PrimaryButton/PinField; T4 hero emeraldDeep + tag SURPLUS gold; T5 ring budget (rust jebol / gold 1 urgent / emerald on-track) + donut emerald/rust/gold + rekap ala TxRow. T6 sapu: separator `·` (`datetime.dart` + test), `emeraldBright #45B79B` dark (emerald exact 1.91 gagal AA → bright 7.69 dua arah; onPrimary dark = bgDark; thumb switch bgDark), chip neutral sadar-tema (dark lineDark/inkSoftDark 5.74), ukur bgDark-on-gold 7.86 AAA + rust-putih 5.94 AA, rekap out-only terkonfirmasi (`reports_screen.dart:154,163`), TextButton dark → bright (7.69). Ruling rust: teks AA hanya di surface terang; di surfaceDark (2.93) untuk fill/grafik saja. T7/T8: migrasi 30 file sisa hingga grep noir/teal NOL (noir resmi dihapus). CI hijau `36313239571` (analyze 0, 212 test; fix: param soft tak terpakai). Bump `2.4.2+25` (pubspec + AppInfo identik). |
| `932c420`+`94c1201` (run `36359719439` hijau, 218 test) | **Fix 5 bug user + 2.4.4+27** (investigasi 3 subagent read-only, eksekusi sekuensial + self-review; review menemukan delegate search kembalikan `route` bukan titleKey → 6 entri hub pakai route distinktif; CI merah 1x: `parseAmountValue('15000.0')` → 150000 karena fix setengah — buang titik tanpa nolnya; pelajaran: `dart` lokal wajib `--enable-asserts` else PASS palsu): (1) `setThemeChoice` terima `otomatis`+`noir` (invalid tetap no-op, test diperketat round-trip); (2) CSV round-trip: `.0`/`.00` buang titik+pecahan, `.000` ribuan, `10.5` desimal, alias `dompet_id`/`ke_dompet_id`, match id UUID, mapping tampil saat 0 baris, `imp_need_wallet`, ekspor laporan kolom dompet + nominal bulat; (3) `categoryMeta` notifier + `svgForMetaIcon`/`metaSlotColor` di TxRow + rekap (fallback = ledger lama); (4) kartu Lang/Currency/Font reaktif, `SettingsScreen(focus)` + auto-scroll dari 4 pintu hub, search hub beraksi nyata; (5) `_PinCard` `checkOld` (verifyPin + lockout `lk_lockout`, tanpa-PIN langsung baru) + email jadi "Lupa PIN?". APK `SSR-SPACE-2.4.4-27-fix-5bug-arm64.apk` |
| `6a3f01f` (run `36361554023` hijau, 220 test) | **Ikon WYSIWYG + Bantuan + avatar Profil + changelog jujur (2.4.5+28):** (A) `_CatRow` ikon outline → `SvgPicture` resolusi TxRow (SS user: layers-outline vs kartu-wallet); (B) `changelog_id.md` basi 2.3.9+22 → ditulis ulang + aturan §7 AGENTS (bump = entri changelog); (C) `HelpScreen` tutorial 6 + FAQ 6 (`hp_*`, `help_test.dart` 2 test ID/EN non-fallback), hub + search; (D) leading avatar inisial → `_select(4)`. APK `SSR-SPACE-2.4.5-28-bantuan-profil-arm64.apk` |
| `1bb6720`+`1e7f0ec` (run `36365717961` hijau, 222 test) | **Notif tiap tersimpan (2.4.6+29):** `offer()` overlay-dulu-gagal→head-up + `forceSave` ikut offer; `AutoSavedNotify` + `auto_saved_notify_test.dart`; CI merah 1x (named args v22). APK `SSR-SPACE-2.4.6-29-notif-tersimpan-arm64.apk` |
| `d1340a0` (run `36367696687` hijau) | **Head-up selalu tampil (2.4.6+30):** blokir overlay silent tak terdeteksi → fallback bersyarat mati; kini head-up unconditional tiap offer. APK `SSR-SPACE-2.4.6-30-notif-headup-arm64.apk` |
| **T7/T8** | **Migrasi token tema → AppColors/AppTheme seragam**: hapus `SsrColors` + `SsrTheme` (30+ file), `SsrTheme.money`/`moneyLarge`/`moneyOnDark` → `AppTheme.money`/`moneyLarge`, `main.dart` pakai `AppTheme.light()`/`AppTheme.dark()` langsung (noir → `themeMode: ThemeMode.dark`). `SsrTheme.noir()` resmi dihapus. Bump `2.4.8+35`. |
| `01dd525` | **Fase 0 (2026-09-28):** (1) `session_service._set` tambah handler `double` + `List<String>` — font scale & list prefs tidak persist silent; (2) `completeOnboarding` reset `lastActiveAt` — auto-lock jalan langsung setelah onboarding; (3) `main.dart` wrap `CurrencyService.refresh()` dalam try/catch — crash silent kalau network error; (4) bump `2.4.8+35` → `2.4.9+36`. CI hijau (run `36388775858`). |
| (PIN design, run CI berikut) | **Desain PIN lebih sederhana (2.4.9+37):** `PinField` — hapus `AnimatedContainer` → `Container` static, hapus highlight `isCurrent` (hanya `filled`/unfilled), box lebih kecil (34×40, radius 12), border tipis 1px, gap 6px, error fontsize 12, `cursorColor: Colors.transparent`, `enableInteractiveSelection: false`; `LockScreen` — hapus dekorasi container ikon kunci (DuoIcon langsung), spacing ramping; `OnboardingScreen` — hapus `_stepDots` (sederhanakan onboarding). APK `SSR-SPACE-2.4.9-37-pin-simple-arm64.apk`. |
| `TBD` | **Batch 2 Premium Fintech 2026 (2.61.0+165)**: Beranda redesign — hero GlassPanel + entrance animation (fade+scale), Transaksi Terakhir pakai PremiumSectionHeader + GlassCard, dashboard header → PremiumSectionHeader |

APK artefak: run Actions hijau terakhir → artifact `ssr-space-apk`.

---

## 8. Cara baca doc ini

- **AGENTS.md** → cara kerja, workflow, aturan jangan-dilanggar.  
- **AUDIT.md** (ini) → kenapa kode begini, apa yang sudah / belum, urutan lanjutan.  
- Spec historis → `docs/superpowers/specs/2026-09-23-ssr-space-design.md` (baca bagian update).
| (theme chooser, run CI berikut) | **Pilihan tema Otomatis+Noir** (SDD 7 task, tiap task review CLEAN; spec `2026-09-27-theme-chooser-design.md`): T1 prefs `app_theme_choice` + notifier `themeChoice` (default `otomatis`, fail-safe) + restore `SsrTheme.noir()` + 6 token noir dari commit `0bdeb7b` (radius pakai SsrRadius sekarang) + wiring `main` (ValueListenableBuilder terluar; noir → theme+darkTheme kembar, themeMode tetap system) + strings `st_theme`/`th_auto`/`th_noir`/`th_theme_desc` + test prefs + bump `2.4.3+26`; T2-4 konversi 127 `AppColors.` mati di 14 file → colorScheme per aturan mapping spec §3 (emerald→primary, ink→onSurface, line→outline, rust→error, cream→onPrimary/surface, bgDark→surfaceContainerLowest; emeraldDeep/gold/chip TETAP; hero text brightness check lokal; correct_overlay TETAP — standalone gelap by design); T5 `_ThemeCard` SegmentedButton di settings (pola `_LangCard`, ganti langsung via notifier); T6 `ThemeStepScreen` setelah consent sebelum auth (user lama tak melihat). Ruling: overlay tak dikonversi; radius noir pakai SsrRadius sekarang; `st_theme` ditambah. |
| (PIN pad, run `36405433332` hijau) | **Desain PIN + pad on-screen (2.4.10+38):** vonis SS user "design pin jelek banget": akar = regresi `3f43bbb`: TextField `PinField` tak lagi `Opacity(0)` → kena `focusedBorder` tema (`app_theme.dart:183`) → pil emerald full-width nempel di belakang 6 kotak; empty border `outline 0.4` (delta ~6/255) nyaris invisible. Fix: `PinField` display-only (nol TextField → bug+IME hilang di akar; kotak 40×48 gap 8, empty outline penuh / filled primer 8% / selected primer / error); `PinPad` (4×3, `NumpadKey` ekstrak dari `TxNumpad` → `numpad_key.dart`, menulis via `pinKeyInput` murni: nol di depan sah, lokal `dart --enable-asserts` 12/12 termasuk regresi `numpadAppend`); `LockScreen` badge lingkaran lock 56px + headlineSmall + **auto-verify 6 digit** (tombol Buka dihapus, salah → `pinC.clear()` + guard `_verifying` anti double-nav); onboarding + `_NewPinForm` → StatefulWidget (`_activePin`: auto-advance saat 6 digit, ketuk kotak pindah kolom); pad di `pin_dialog` + konfirmasi hapus budget (content `SingleChildScrollView`, aman landscape) + settings `checkOld`. Test: 3 case `pinKeyInput` di `tx_input_test.dart` + `test/pin_field_test.dart` (3 widget test: dot/onCompleted sekali+guard, error, pad maxLen). Tanpa dep/migration baru; copy tak berubah selain tombol Buka; changelog 2.4.10 ✓; bump `2.4.10+38` (pubspec+AppInfo identik). CI merah 1x (`d937794`): `test/pin_field_test` gagal bangun `NumpadKey` karena `Material` terima `borderRadius`+`shape` sekaligus (assertion `material.dart:209`, warisan kode `TxNumpad` lama, latent: tak pernah dibuild test & assert mati di APK release) → fix `8340ca8` hapus `borderRadius` dari `Material` (render identik, `shape` sudah bawa radius sama). Run `36405433332` hijau penuh (analyze + test + build, 11m12s). |
| (nfc, run `36420797043` hijau) | **E-Money NFC 2.4.11+45** (spike A LULUS device Mandiri: saldo = balance histori terakhir, tipe 1=kredit/2001=debit, histori sort counter desc, init=false bukan gate; dep pin `prepaid_lib_flutter_null_safety: ^1.0.1` + 4 patch CI: jcenter→mavenCentral, namespace, jvmTarget 1.8, compileSdk 35; minSdk app 24→26; izin NFC required=false): `nfc_emoney_logic.dart` murni (8 test incl. toleran angka-string — NEEDS_CONTEXT implementer terbukti benar) + `nfc_emoney.dart` (initOnce/read/prefs `nfc_cards` cap-20 + `nfc_history_checks` cap-50, read-only tanpa top-up) + `nfc_cards_screen.dart` (daftar + sheet hasil + taut dompet + hapus; tile hub Data; spike dihapus) + 20 kunci `nfc_*`. Tanpa migration. Batas sadar: Flazz/TapCash/JakCard belum terbukti device (fail-soft); vendor unverified (fallback C = UID-link); 4 patch = utang tiap bump toolchain. APK `SSR-SPACE-2.4.11-45-nfc-arm64.apk`. |
| (optimalisasi, run `36447227862` hijau, 260 test) | **Optimalisasi 2.5.0+47** (spec + plan 2026-09-28, brainstorm penuh + 7 skill): P1 `WalletCache` (TTL 60 dtk, `test/wallet_cache_test.dart` 4 case) + `Future.wait` dingin + debounce 300 ms; P2 nav 4 tab + Profil via avatar (hapus `nav_lainnya`); P3 hapus koreksi instan total (5 file, dep overlay, inject CI, `pinNotice`, 20+ kunci `ic_*`/`fg_correct`/`st_reset_correct`, grep NOL) → `showSaved` + `savedBody` (`test/auto_saved_notify_test.dart` 5 case, format `amt` sama dgn summary lama) + `tx_detail_sheet.dart` via `last_detail_tx`; P4 `nextWeekly` (lokal `dart --enable-asserts` 6/6) + id 7002 `dayOfWeekAndTime` + `wd_1..7`. CI merah 1x (`initialize` v22 named-only + unused import) → fix `15849e3`. Tanpa migration/dep baru; bump `2.5.0+47` + changelog. APK `SSR-SPACE-2.5.0-47-optimalisasi-arm64.apk`. |
| (nfc-dompet, run `36435488420` hijau) | **Gate NFC + kartu→dompet + kelola dompet (2.4.12+46):** A: dep langsung + banner 3-state; B: `linkCardAsWallet` (create→taut→opening, rollback) + `nfcAdjustmentFor` murni TDD + sheet Catat/Lewati; C: `WalletService` return-id/rename/type/hasTransactions/delete + edit dialog + hapus PIN + saldo-awal form. Tanpa migration. Batas sadar: Flazz dkk best-effort; opening menaikkan pemasukan (by design). APK `SSR-SPACE-2.4.12-46-nfc-dompet-arm64.apk`. |
| (2.7.0+49, run `36510352640` hijau, 277 test) | **Ekspor ikut filter + simpan Documents + notif Bagikan + full Coolicons** (`5539914` + fix `5d219f6`; CI merah 1x: `permission_handler ^13` menarik android 14 butuh compileSdk 37 vs app 36 → pin exact `12.0.3`/android 13.0.1/SDK 35, bukti tarball): (A) `report_export.dart` murni (`applyReportFilters` dompet+jenis dipakai list+ekspor, `exportBaseName` sanitasi; lokal `dart --enable-asserts` 20/20 + `test/report_export_test.dart` 12 expects) — CSV ikut filter (round-trip penuh dihapus per putusan user); `report_pdf.dart` premium (baris filter kop, kolom Dompet transfer `A → B`, kepala emeraldDeep, selisih surplus goldSoft, rekap + bar progres, flex anti-nol); (B) `export_files.dart` (`Documents/ssr-space/`, MANAGE≤30+/WRITE klasik, non-Android ke dokumen app; ditolak → `ExportNoPermission` → fallback temp+share+pesan jujur) + `export_saved_notify.dart` (channel `ssr_export_saved` HIGH + aksi Bagikan via payload path; tap badan buka app saja) + izin diinject `apk.yml` (WRITE maxSdk29 + MANAGE + legacy flag); gate kuota PDF tetap; (C) `DuoIcon` render Coolicons via `CoolSvg.pathForCodePoint` (58 primer, tabrakan hanya entri mati, fallback legacy Phosphor; 49 situs nav otomatis ikut, nol konversi call-site) + subset repo 60 SVG (248K) + 6 ledger `cat_invest/donate/family/sport/pet/sos` disambung di `svgForCategory` (cabang lama nol berubah) + kredit CC BY di Tentang. Dep baru `permission_handler ^13.0.2` satu saja. Tanpa migration. Batas sadar: share dari notif butuh ketuk buka app dulu (Android tak izinkan sheet tanpa foreground). |
| (we-space, run `36462622027` hijau, 265 test) | **We Space 2.6.0+48** (spec + plan 2026-09-28, brainstorm + writing-plans + executing-plans, eksekusi inline 7 task): `migration_15` (kolom `space_mode`, helper `can_write_space`, pecah policy tulis wallets/tx, RPC `set_space_mode`, trigger `tx_manual_insert`, audit kick; T16–T20 **lulus lokal** via Postgres Termux) + `space_logic` murni (15/15 lokal) + `SpaceService` + 13 kunci `sp_*` + badge pencatat `TxRow` (`createdBy`) + switch mode PIN-gate + Aktivitas Space (hub + badge + search) + gate tulis jujur (`SpaceException`, `_txError`, `saveErrorStatus`). Tanpa dep/FCM. Deviasi jujur: `delete_workspace` tanpa audit (cascade menghapusnya). APK `SSR-SPACE-2.6.0-48-we-space-arm64.apk`. |
| (wizard-scan, run `36524609353` hijau) | **Wizard catat 2 langkah + scan struk 2.8.0+50** (spec+plan 2026-09-29, ML Kit on-device — Cloud Vision ditolak: bayar $1.50/1000 + butuh backend key + upload foto): `receipt_parse.dart` murni (TOTAL BELANJA prioritas, tolak KEMBALI/DPP/PPN/HARGA JUAL/PURCHASE, tanggal match-terakhir, merchant INDOMARCO→INDOMARET, item maks 8, voucher terpisah; lokal `dart --enable-asserts` 10/10 + `test/receipt_parse_test.dart`) + `receipt_scan_service.dart` (image_picker intent → tanpa izin CAMERA/apk.yml, foto dihapus) + `tx_input_sheet` wizard (`_step`, grid kategori 2 kolom ikon ledger, scan di langkah 1 → prefill langkah 2 = preview, edit langsung langkah 2, keyakinan rendah → `rcp_partial` fail-open) + 14 kunci `wiz_*`/`rcp_*`. Dep: `image_picker ^1.1.2`, `google_mlkit_text_recognition ^0.15.0`. CI merah 1x: `RecognisedScript` tak ada (API = `TextRecognitionScript`) + kurung `children` kurang satu → fix `c4476d3`. Tanpa migration. Batas sadar: APK arm64 36.4MB (+12M model Latin); nama barang singkatan kasir apa adanya; tanggal terpotong dibaca apa adanya (user koreksi di preview); dompet tetap Most-used. APK `SSR-SPACE-2.8.0-50-wizard-scan-arm64.apk`. |
| (a11y-polish, lokal belum push/CI) | **Polish a11y impeccable 2.8.0+56** (audit native 10/20): 5 IconButton ikon-saja → `tooltip` (`categories`/`recurring`/`nfc` = `tx_delete`, search clear = kunci baru `clear`, search back = `back`) + label `Semantics(tx_delete)` di tombol hapus `TxNumpad`/`PinPad` (impor `strings.dart`) + hardcode `Color(0xFF7A5E14)` di `tx_row.dart:178` → `AppColors.chipSurplusText`. Visual/behavior nol berubah. Diverifikasi: TxRow InkWell sudah ekspos role button; chart fl_chart tanpa teks = dilewati TalkBack, datanya ada di legenda/rekap teks sekitar. Tanpa migration/dep baru; bump +56 + changelog. |
| (optimize-list, lokal belum push/CI) | **Virtualisasi riwayat 2.8.0+57** (temuan P1 audit): helper baru `tx_day_slivers.dart` (flatten day-bucket → 1 `SliverList.builder`, divider pixel-identik per layar) + `sectionCardDecoration()` di `section_card.dart` (kartu digambar via `DecoratedSliver` di dompet/laporan) + `CustomScrollView` di transaksi/dompet/laporan mode baca. Path susun-ulang laporan tetap eager (UI transien). Pixel/behavior nol berubah; `groupDayBuckets` tak tersentuh. Tanpa migration/dep baru; bump +57 + changelog. |
| (distill-ikon, lokal belum push/CI) | **Distill ikon 2.8.0+58** (temuan P1 audit, revisi jujur: full 100% tak feasible — Coolicons set UI tanpa sport/pet/sos): 15 badge kategori ledger → Coolicons subset + invest/donasi/keluarga → Trending_Up/Gift/House_01; sport/pet/sos tetap ledger; Material murni terakhir (`delete_outline` NFC) → `DuoIcon(trash)`; font Phosphor-Duotone 568KB dihapus (fallback mati: 55/55 ikon terpakai resolve ke Coolicons, verifikasi script); `category_meta_test` disesuaikan. Tanpa migration/dep baru; bump +58 + changelog. |
| (ci-infra, 2.8.0+59) | **APK via rilis rolling `ci-apk`**: kuota artifact GitHub mentok (4.5GB, refresh 6–12 jam) → 4 step `upload-artifact` di `apk.yml` diganti `gh release upload ci-apk --clobber` (nama `SSR-SPACE-<ver>-<abi>.apk`) + `permissions: contents: write`; tanpa action baru (supply chain utuh). Unduh: `gh release download ci-apk -D /sdcard/Download/SSR-SPACE/`. Trade-off: arsip per-run hilang, tersisa 1 set terakhir. Tanpa migration/dep baru; bump +59 + changelog. |
| (budget-alerts, 2.8.0+60, branch `feat/budget-alerts`) | **Peringatan budget real-time** (SDD 4 task: trigger + RLS `migration_16` + banner/badge + `warn_pct` custom + review/fix; assert RLS T21–T25; tanpa dep/backfill baru). **User wajib jalankan `migration_16` manual** (setelah migration_15), kalau tidak banner tak muncul. |
| (fix-scan, 2.8.0+61, lokal belum push/CI) | **Fix scan struk Opsi A** (vonis systematic-debugging: 7 fix konversi gambar `743947a`→`3185790` gagal identik → layer salah; tersangka = R8 strip class ML Kit, bukti issues #528/#744): step `apk.yml` tulis `proguard-rules.pro` + wiring release (KTS/Groovy, idempoten, assert keras); service kembali `fromFilePath` resmi; dep `image` dilepas; `receipt_nv21_test.dart` dihapus; parser/strings/sheet nol ubah. Foto tetap dihapus `finally`, tanpa upload, `detail` truncate 220 char tanpa teks OCR. Batas sadar: ROM tanpa Play Services update bisa tetap gagal init model. |
| (fix-parser, 2.8.0+62) | **Fix parser total Indomaret, TDD** (device 2.8.0+61: OCR jalan, total null → Rp0 + `rcp_partial`; teks bersih user lolos parser lama → OCR device pasti cacat): `_isTotalLine` toleran (spasi + 0/O), prefix pra-tunai/kembali di baris gabung, intip baris-berikut murni-angka. RED lokal 4-merah (H1a/H1b/H2/H3) → GREEN 10/10 (`dart --enable-asserts`); 6 test baru + struk nyata `_t3` (25.000, jebakan postcode/NON TUNAI/DPP/PJK/HARGA JUAL); 10 test lama wajib hijau di CI. Tanpa upload/foto-dihapus tak tersentuh. |
| (ocr-debug, 2.8.0+63) | **Dialog teks OCR mentah** (device 2.8.0+62 tetap Rp0 + `txv_amount` → parser benar, teks device cacat; butuh bukti asli bukan tebakan): `lastRawOcrText` (reset tiap scan, memori saja) + dialog `SelectableText` tiap scan selesai + 3 kunci `rcp_raw_*`. Aman: tanpa upload, foto tetap dihapus, teks mentah tak masuk error report/DB/transaksi. |
| (parser-acak, 2.8.0+64) | **Parser tahan OCR-acak, TDD** (bukti mentah: TOTAL tanpa angka + 25rb nyasar ×3): prioritas TOTAL → `PURCHASE:` → modus standalone (≥2 suara, seri = null); peek H2 dipersempit (1 angka nyasar saja — temuan RED: comot TUNAI 50rb). RED 5-merah → GREEN 5/5 lokal; 5 test baru (`_t4` + purchase/modus/seri). |
| (grand-cacah, 2.8.0+66) | **Grand + anti-cacah + tanggal, TDD** (BANGOR 73.636 vs 81.000; KOPI Rp1 + 2029): grand override; grand cacat → tender e-money, tunai hanya tanpa KEMBALI; `_okAmount` ≥100 + baris cacah dilewati; tahun ≤ now+1. RED 4-merah → GREEN 8/8 + regresi lama 7/7 lokal; 8 test baru (`_t5/_t6` + grand/tunai/cacah/threshold/tanggal). |
| (aritmetika, 2.8.0+68) | **Relasi aritmetika, TDD** (Kopi 2.8.0+67 Rp0: label tanpa angka + 6 angka @1x): triple tunai-kembali → nilai tengah (1 set + label; debug: 1 triple = 2 bacaan) + jumlah-item subset (guard kode/tanggal/voucher, cap 12). RED 4-merah → GREEN 5/5 + regresi 15/15 lokal; 5 test baru. |
| (item-produk, 2.8.0+69) | **Item hanya produk, TDD** (note device sampah persis reproduksi RED): nama ≥3 huruf + harga ≥100 + `_fragKey` + `_isTotalLine` di loop item. RED 2-merah → GREEN 5/5 lokal; 3 test baru (`_t8` + note + NPWP). |
| (anti-kontak, 2.8.0+70) | **Anti-sampah kontak, TDD** (`19,900 · ihatsApp + 7818`): merchant butuh huruf + `_phoneLine` + fragKey kontak + merge fragmen + tolak caps-tengah. RED 6-merah → GREEN 8/8 lokal; 5 test baru. |
| (form-jelas, 2.8.0+65) | **Form catat jelas (audit F1–F9) + OCR semua kategori** (claim visual: CI analyze+test hijau; verifikasi device ikut user): B1 D1–D9 — label Nominal, error per-field, chips aksen, caption ketik-cepat, Langkah 1/2 + Kembali, hint tanggal, helper transfer, banner asal-struk, sub lipat; 9 kunci strings; `validateTxField` + test, `category_chips_test` widget. B2 `receipt_kind.dart` (registry pola + suggest guard-daftar, 8 test lokal 8/8) dipakai sheet saat scan. Tanpa migration/dep/upload; foto tetap dihapus. |
| (polish-fix8, 2.12.1+75, run `37899152461` hijau) | **Polish + 8 temuan, antislop-ui/layoutmobile** (tanpa bahasa visual baru): gear settings AppBar Beranda → `SettingsScreen` langsung (DuoIcon settings existing); search bawa focus (`focus` per entri + 7 GlobalKey baru, fallback key terdekat); chevron outline → onSurfaceVariant. Fix: try `_guardPdf` + snackbar jujur; `_parts` toleran (rusak → bulan berjalan); `length<10` di 3 parse tanggal; `mounted` di 6 `_load`; hapus `kSearchP2/kSearchHub` + cek mati; komen 4 tab. Test CI: guard bulan + tanggal kompak. Langsung hijau, tanpa merah. APK `SSR-SPACE-2.12.1-75-arm64.apk` (pola `-p` spesifik). Sisa audit: invite `DateTime.parse` (kolom NOT NULL) + `dashboard_service` yatim → backlog. |
| (game, 2.12.0+74, run `37893446103` hijau) | **LOOP 4 Gamifikasi, TDD** (tanpa migration/dep baru; XP deterministik dari state, bukan event log): `game_badges.dart` (8 badge, seen prefs, chip Baru sekali) + `game_challenge.dart` (3 template opt-in, evaluasi live minggu berjalan) + `game_level.dart` (XP = tx capped 200 + streak + tantangan + goal; 7 level) + `game_store.dart` + `ArcadeScreen` hub Data (level + grid badge + tantangan) + `_LevelRow` Beranda (pakai hist 12-bln existing, nol query baru). RED lokal: ekspektasi nospend salah (5 bersih = selesai) → GREEN 24/24 `dart --enable-asserts`; 3 file test CI (11 case). CI merah 1x (`int?` lolos cek `!=`, pelajaran: null-check eksplisit sebelum konstruktor). APK `SSR-SPACE-2.12.0-74-arm64.apk` (pola `-p` spesifik). |
| (goals, 2.11.0+73, run `37891373844` hijau) | **LOOP 3 Goals, TDD** (tanpa migration/dep baru; setor manual = progres prefs, bukan transaksi): `savings_goal.dart` murni (mode auto/manual, `since` akrual jujur, parse toleran, cap 20) + `goal_store.dart` (prefs JSON) + `goal_forecast.dart` murni (avg/bln → proyeksi bulan, need+extra vs deadline, overdue; avg nol = null) + `emergency_fund` (3 level dari 3x/6x belanja) + `GoalsScreen` hub Data (tambah/setor/hapus, forecast per kartu) + `_DreamCard` Beranda (status darurat + goal terdekat, 1 query 12-bln dipakai bareng insight). RED lokal: ekspektasi darurat salah (5jt < 6jt) → GREEN 26/26 `dart --enable-asserts`; 2 file test CI (9 case). CI merah 3x: import hilang + `DecoratedBox(color:)` + focus di widget salah + unused import (pelajaran: tulis layar baru jangan sekaligus, cek pola SectionCard/TextField dulu). APK `SSR-SPACE-2.11.0-73-arm64.apk` (pola `-p` spesifik). |
| (smart-nudge, 2.10.0+72, run `37878590894` hijau) | **LOOP 2 Smart Nudges, TDD** (tanpa migration/dep baru, offline-first): nudge pace maks 2 per kategori warn/danger (`paceNotes`, sort bahaya + tanggal terdekat, copy `nudge_*` casual); `weekly_insight.dart` murni (total minggu lalu vs rata-rata 4 minggu, top naik + %, saran potong 20% dibulatkan ribuan; dismiss `insight_seen_<W>_<org>`; tampil saat dibuka, bukan push) + `listRange` + `_NudgeCard`/`_InsightCard` di Beranda; `month_compare.dart` murni (delta + % per kategori, urut |delta|) + `_CompareCard` di `_summarySection` Laporan (ikut filter dompet, panah + % berdampingan, 3 teratas tebal). RED lokal: off-by-one minggu (diff 7 hari = 1 minggu, bukan 2) + ekspektasi weekKey ISO salah + float last-bit → GREEN 23/23 `dart --enable-asserts`; 2 file test CI (6 case). CI merah 2x: `_ymd` ganda + `!` tak perlu (info = fatal). 12 kunci strings + changelog. APK `SSR-SPACE-2.10.0-72-arm64.apk` (pola `-p` spesifik). |
| (daily-touch, 2.9.0+71, run `37874816407` hijau) | **LOOP 1 Daily Touch, TDD** (tanpa migration/dep baru, offline-first hitung lokal): (1) streak harian di `calm_streak.dart` (`dailyStreak` + `nextMilestone`/`isMilestone` 7/30/100, grace 1 hari: hari ini kosong + kemarin ada = streak aman; bolong tengah tetap putus); (2) `health_score.dart` murni (budget 40 / nabung target 20% = 30 / tren vs bulan lalu 20 / streak 10; tanpa budget = 70 netral; tabungan dikecualikan dari belanja); (3) `budget_pace.dart` murni (aman / waspada habis < akhir bulan + tanggal proyeksi / bahaya jebol-atau-≤7 hari; tabungan dikecualikan). Beranda: `_StreakCard` + `_HealthCard` (delta vs kemarin via prefs + dialog rincian 4 komponen) + `_PaceBanner` (ketuk buka Budget); health/pace hanya bulan berjalan, fail-open sembunyi. Budget: `_PaceLine` titik warna + kalimat per kartu. Helper: `listDates` ringan + `fetchBudgetLimits`. RED lokal 1-merah (ekspektasi waspada salah: 600rb/9 hari = 6 hari lagi = bahaya, benar) → GREEN 25/25 `dart --enable-asserts`; 3 file test CI (18 case). 17 kunci strings casual ID/EN + `close`. APK `SSR-SPACE-2.9.0-71-arm64.apk`. |
| (fix-fc2131, 2.13.7+84) | **Fix FC 2.13.1 aman** (systematic-debugging; tanpa bypass, PIN tetap jalan): (H1) MethodChannel `ssr_space/widget` + broadcast native tiap Beranda = DISABLE sementara (`today_widget.dart` prefs-only + komen alasan; `_pushTodaySnapshot` try-catch + `catchError`; `apk.yml` tanpa inject channel); (H2) izin notif startup = silent (`scheduleDaily/Weekly` param `interactive=false` default, `main.dart` tanpa dialog; `notificationsAllowed()` + guard `st_notif_denied` hanya di toggle settings `interactive:true`); heads-up `Importance.max`+`Priority.high` dikembalikan (bukan penyebab FC). Tanpa migration/dep baru; bump +84 + changelog. |
| (sprint-b1, 2.14.0+85) | **Sprint Batch 1** (bounded, approved): (1) lupa password — reset email via deep-link PIN yang sama + `consume()` terima `recovery` (flag `passwordRecovery`, reset bareng) + `SetPasswordScreen` + routing Splash/AuthScreen/MainShell; `newPasswordError` murni + `test/password_reset_test.dart` (5 case) + case recovery di `auth_link_parse_test`; (2) invite `tryParseInviteDate` + guard fail-closed + test. Tanpa migration/dep/config baru. Roadmap `docs/SPRINT_ROADMAP.md`, audit `docs/SPRINT_AUDIT.md`. |
| (sprint-b2, 2.15.0+86) | **Sprint Batch 2** (bounded, approved): (1) wizard auto-track 3 langkah (`track_wizard_screen.dart`: izin + master + mapping via `BankTrackRow`, PageView terkunci, Lewati selalu ada; entry tombol + banner dismissable di notif_settings, flag `track_wizard_done`); (2) pagination Transaksi (`listMonthPage` range + `txPageHasMore` + `test/tx_pagination_test.dart`, scroll-controller infinite scroll + footer + caption `tx_partial`/`tx_all_shown`); `listMonth` lama utuh (beranda/laporan Batch 3). 21 kunci `wz_*`/`tx_*` ID+EN. Tanpa migration/dep. |
| (sprint-b3, 2.16.0+87) | **Sprint Batch 3** (keputusan Hibrida, approved): kuota server-side — `migration_17_quotas.sql` (`org_plan` + RPC `check_quota` auto/members/workspaces + 3 trigger BEFORE INSERT → `QUOTA_EXCEEDED`; kompatibel fixture lama) + assert RLS T28 (150 auto + RPC jujur) / T29 (anggota ke-4 + NOT_MEMBER/kind + pro bebas) / T30 (workspace ke-3) — **lulus lokal** via Postgres Termux (`SUKSES`) sebelum push; klien server-dulu-lokal-fallback + `saveErrorStatus`/`iv_quota` + Billing jujur (`bl_soon`, tombol palsu + state upgrade dicabut). Pelajaran: count SELECT kena RLS baca-sendiri → assert pakai RPC `list_org_members`; var `v_plan` jangan dipakai ganda (text vs int). Tanpa dep baru. |
| (sprint-b4, 2.17.0+88) | **Sprint Batch 4** (bounded, approved): (1) Google — `google_sign_in ^6.3.0` (hindari breaking 7.x), `signInWithGoogle()` native-dulu-browser-fallback + tombol auth + listener sesi guard `_navigated`; (2) biometrik — `BiometricAuth` fail-closed + `biometricEnabled` (OFF default, test ext) + kartu settings + LockScreen auto/manual + `markUnlocked()` (+ test session); `secure_storage` ditunda jujur. CI: `USE_BIOMETRIC` + `google-services.json` kondisional. Verifikasi akhir = device (native perlu SHA-1 + provider ON). Tanpa migration. |
| (sprint-b5, 2.18.0+89) | **Sprint Batch 5** (bounded, approved): (1) angka eksak — `month_mix` RPC + `foldMonthMix` murni (+`mixRowsFromTx` fallback, `test/month_figures_test.dart` 5 case) + `monthMix()`; Beranda hero/health/pace dari fold, display halaman-1, count `figN`; Laporan rekap/banding dari fold, display infinite scroll + footer, ekspor full-load cap-2000; (2) heartbeat 3 lapis (tabel + RPC + cron guarded + `heartbeat.yml`/3 hari + touch harian main, max 1/hari). RLS T31/T32 **lulus lokal** (`SUKSES`); pelajaran: outer SELECT tanpa FROM + var ganda + RLS deny-all menutupi assert (cek superuser). Tanpa dep baru. |
| (sprint-b7, 2.19.0+93) | **Sprint Batch 7** (bounded, approved): squash 16 file 02..19 → `migration_squashed.sql` (verbatim + guard pg_cron; dump schema-only vs rantai lama **identik kecuali token sesi acak**; suite 78 asserts hijau via baseline baru; `run.sh` tanpa skip) + hapus `dashboard_service`(+test)/`requestUpgrade`/`flutter_secure_storage` (grep nol referensi). Pelajaran: `pg_dump` token `\restrict` acak tiap run — bukan perbedaan skema. Tanpa migration manual. |
| (fix-google-native, 2.18.0+90) | **Fix native Google login**: `serverClientId` (Web client ID user via secret `GOOGLE_WEB_CLIENT_ID` → dart-define, bukan hardcode) dikirim ke `GoogleSignIn` + log alasan gagal native; wiring 2 build command. |
| (sprint-b11, 2.23.0+97, run `38116277422` hijau) | **Sprint Batch 11 Smart Subscription Tracker** (bounded, approved: semua-pengeluaran + Jadikan/Abaikan): `subscription_detect.dart` murni (grup label+nominal, jeda 21–40 hari, 3x=Pasti/2x=Mungkin, transfer/masuk/rusak/nol/kosong dibuang; TDD RED gagal-file-hilang → GREEN 14/14 lokal `dart --enable-asserts` + batas 21/20 lolos/tolak, `test/subscription_detect_test.dart` 10 test) + `SubscriptionsScreen` hub Data (pindai 4 bulan via `listMonth` fail-open per bulan, total/bulan + count, chip Pasti/Mungkin/Baru(ink)/Otomatis, Jadikan tagihan prefill `RecurringBill` monthly + guard dompet/cap-30, Abaikan prefs `subscription_ignored` cap-100 + tampil/sembunyi) + 18 kunci `sub_*` + tile hub ikon calendar (tanpa search-entry, konsisten bills/goals). CI merah 1x (`dangling_library_doc_comments` kepala `///` → `//`). Tanpa migration/dep. APK `SSR-SPACE-2.23.0-97-arm64.apk`. |
| (sprint-b12, 2.24.0+98, run `38117944361` hijau) | **Sprint Batch 12 Bill Splitter** (bounded, approved: prefs-lokal + lunas=status): `bill_split.dart` murni (`equalShares` sisa-ke-pertama, `validateCustomShares` empty/nonPositive/mismatch, `debtsOf` lewati payer+lunas, `settledCount`/`isFullySettled`, `shortMemberLabel` + `meSuffix` i18n; TDD RED gagal-file-hilang → GREEN 24/24 lokal, `test/bill_split_test.dart` 11 test) + `BillSplitsScreen` hub Data (tile ikon transfer; wizard 3 langkah: tx `out` via `list()` + judul fallback, peserta centang + payer dropdown default Saya, Rata/Custom + pratinjau; detail "{a} berutang {m} ke {b}" + lunas/batalkan + hapus PIN-tanpa; store prefs cap-30, judul-kosong pre-save review) + 24 kunci `bs_*`. CI merah 1x (`ssrSegmentedStyle` di `tx_type_selector` bukan `app_theme`). Tanpa migration/dep. APK `SSR-SPACE-2.24.0-98-arm64.apk`. |
| (sprint-b13r, 2.25.0+99, run `38124510760` hijau) | **Sprint Batch 13 Revisi Utang-Piutang** (target-nabung STOP user — sudah ada di GoalsScreen, revert bersih; bounded, approved prefs-lokal): `debt_track.dart` murni (`DebtRecord` kind utang/piutang + `DebtPayment` riwayat, `remaining`/`isSettled`, `applyPayment` cap, `validatePayment` nonPositive/over, `debtTotals`; TDD RED gagal-file-hilang → GREEN 22/22 lokal, `test/debt_track_test.dart` 10 test) + `DebtsScreen` hub Data (total sisa dua jenis, form + date-picker, detail + Bayar default-sisa + riwayat + hapus; prefs `debts` cap-50) + 25 kunci `db_*` (pelajaran: cek tulisan aneh sebelum commit — `db_pay_hint` sempat `Nominal训练≤`). CI: analyze+test hijau, split-APK exit-143 (SIGTERM runner, bukan kode) → rerun hijau. Tanpa migration/dep. APK `SSR-SPACE-2.25.0-99-arm64.apk`. |
| (sprint-b14, 2.26.0+100, run `38126792655` hijau) | **Sprint Batch 14 Export Excel** (bounded, approved 1-sheet+filter): dep `excel_plus ^2.23.0` (MIT pure-Dart, review docs: autoFilter+freeze+rename/`[]`/save/rowsAsMaps terkonfirmasi, tanpa tebak API) + `report_xlsx.dart` (sheet Transaksi, header = CSV, nominal angka Int/Double, autoFilter A1:Gn, freeze 1 baris) + `_exportXlsx` + tombol XLSX `_MonthlySummary` (reuse `_saveAndNotify`, gratis spt CSV) + `r_share_xlsx` + `test/report_xlsx_test.dart` (4 test). TDD RED gagal-file-hilang (probe mentok resolusi dep lokal — wajar, tanpa pub get); GREEN via CI langsung tanpa merah. Tanpa migration. APK `SSR-SPACE-2.26.0-100-arm64.apk` (40M). |
| (sprint-b15, 2.27.0+101, run `38128457828` hijau) | **Sprint Batch 15 Widget Home** (bounded, approved instan-via-channel): snapshot +text2 (kompatibel), `refreshBudgetWidgetSnapshot` query-sendiri + channel refresh hanya-jalur-simpan (timeout 2 dtk, fail-silent; FC 2.13.1 tak terisolasi — dual-disable — jadi eksposur dipangkas dari tiap-load ke tiap-simpan) + Beranda inline `_snapBudgetLeft` + inject (line2+GONE, periodik 30 mnt, channel 2-template + assert). Test: text2 round-trip + `widgetBudgetLeft` + CI (YAML + 16 blok python dicek lokal). Tanpa dep/migration. APK `SSR-SPACE-2.27.0-101-arm64.apk`. Sisa: verifikasi gambar + pantau `client_errors` di device. |
| (sprint-b16, 2.28.0+102, run `38130492750` hijau) | **Sprint Batch 16 Dashboard** (architectural: tanya→pendekatan A→4 seksi→spec→plan→native; putusan: 4 tab tetap): `dashboard_cards.dart` murni + `test/dashboard_cards_test.dart` (TDD RED file-hilang → GREEN 18/18; ruling serialize→stringList) + seksi bawah hero (hero fixed, header Susun/Selesai, dispatcher + panah/mata) + budget traffic-light Top-3 (warnPct, bar, CTA, sembunyi bulan-lampau) + grid 8 deep-link + utang ringkas prefs + 9 kunci `dash_*`. CI langsung hijau. Tanpa migration/dep. APK `SSR-SPACE-2.28.0-102-arm64.apk`. Minor deferred: tooltip panah generik. |
| (sprint-b17, 2.29.0+103, run `38131845528` hijau) | **Sprint Batch 17 Cash-Flow Forecast** (bounded, approved seksi Laporan): `cashflow_forecast.dart` murni (run-rate 30d + tagihan di tanggal nextDue + skenario waspada jujur; TDD RED gagal-file → GREEN 10/10 lokal, 6 test) + `_ForecastCard` (LineChart + titik merah + garis nol + akhir-bulan + banner minus, mask/scheme-aware) + load fail-open 3 sumber + 4 kunci `cf_*`. Langsung hijau. Tanpa migration/dep. APK `SSR-SPACE-2.29.0-103-arm64.apk` (40M). |
| (fix-xlsx, 2.29.0+104, run `38133668958` hijau) | **Fix Excel rapih** (SS Excel bukti 5 cacat; vonis per item, bukan tebak): lebar isi (`xlsxFitWidth` murni, TDD 5/5 lokal) + tanggal sel-date full + nominal `#,#` + header bold/teal/putih + indent + judul 22px. CI merah 2x (named-only + sintaks test) → hijau. APK `SSR-SPACE-2.29.0-104-arm64.apk`. Verifikasi kerapian akhir = SS device user. Batch 18 (voice) ditunda user, file-nya tetap uncommitted di tree. |
| (sprint-b18, 2.30.0+105, run `38135041795` hijau) | **Sprint Batch 18 Voice Input** (bounded, approved; unimpaired oleh jeda fix-xlsx — file tak tersentuh): mic ketik-cepat → STT id-ID → `normalizeSpoken` → prefill existing → simpan manual. TDD normalizer 5/5 lokal. CI merah 2x (API 7.5: deprecated params → `SpeechListenOptions` + `listenOptions`, vonis docs). Tanpa migration. APK `SSR-SPACE-2.30.0-105-arm64.apk` (40M). Verifikasi mic + hasil di device (butuh internet). |
| (fix-voice-silent, 2.30.0+106, run `38136908634` hijau) | **Fix mic diam** (laporan: izin→mendengarkan→bicara→tap→nol respon; systematic-debugging tanpa logcat device): vonis lapis — (d) `listen()` abaikan bool + tanpa `onError` = error recognizer mati sunyi (hipotesis utama, jelaskan 100% gejala); (a) init OK via bukti alur; (b) manifest OK via bukti dialog + tambah assert; (c) locale fallback ada; verifikasi docs: return `listen()` mentah dynamic (jangan di-cast) + `isListening`/`hasPermission`/`errorMsg` stabil → fix: bool jujur + onError→`voiceErrorKey` murni (8/8 lokal) + status selesai-kosong jujur + silang-cek izin. Tanpa migration. APK `SSR-SPACE-2.30.0-106-arm64.apk` (40.200.415 utuh via curl-resume). Verifikasi suara final = device. |
| (fix-voice-107, 2.30.0+107, run `38140252206` hijau) | **Fix mic lanjut** (SS "Gagal mulai mic" = start gagal; riset user 5 poin): default-dulu-retry-id (`voiceLocaleAttempts`, TDD) + guard offline `vc_offline` + docs: `androidIntentLookup` next-step bila tetap gagal. Tanpa migration. APK `SSR-SPACE-2.30.0-107-arm64.apk` (40.200.463 utuh). |
| (sprint-b19, 2.31.0+108, run `38146109305` hijau + voice `38148266464` hijau) | **Sprint Batch 19 (5 fix)**: Fix1 provider anti-FC (guard+Throwable); Fix2 template Excel SSR SPACE (judul merge, TOTAL, border, zebra, Dari/Ke); Fix3 = investigasi (tak ada updater flow — butuh logcat); Fix4 notif ketuk buka file (open_filex + fallback share); Fix5 scan laser + layout struk (dot-leader, dashed, warning) + `splitReceiptItem`. Perjalanan CI: braket Stack (biseksi vs baseline hijau), const Offset, WrapText, spannedItems, dot-infinity, label TOTAL. Voice root-cause: init-sekali + debugLogging + diagnosa locale. APK `SSR-SPACE-2.31.0-108-arm64.apk` (40.332.343 utuh). |
| (fix-ocr-mic19, 2.31.0+108, run `38152083477` hijau) | **Fix OCR Kopi + mic fallback**: RED reproduksi SS persis (PT 19900 + DKI 25000 jadi item); GREEN: zona pra-total berangka + `^(pt|cv|ud)`; regresi t8/t9 sempat 3-merah (TOTAL telanjang ikut batas) → aturan disempurnakan (berangka atau TOTAL:+angka) → lokal 8/8 + CI hijau. Mic: fallback androidIntentLookup saat start gagal (hipotesis tertulis). Cookie hilang butuh teks OCR mentah (minta user). Pelajaran: banding vs baseline hijau dulu sebelum forensik manual (kasus braket Stack). APK final 40.332.383 utuh. |
| (sprint-b22, 2.32.0+109, run `38155384591` hijau) | **Sprint Batch 22 Daily Allowance** (bounded, approved): `allowance.dart` murni + kartu dashboard ke-4 (dot YNAB + Rp/hari + sisa hari; definisi sisa = pace; sembunyi tanpa budget/luar bulan) + registry append-missing (probe lokal tangkap ekspektasi salah sebelum CI). CI merah 1x (info interpolasi) → hijau. Tanpa migration/dep. APK `SSR-SPACE-2.32.0-109-arm64.apk` (40.332.467; unduh malam flaky — resume korup saat server abaikan Range + file sempat hilang misterius → pola loop temp-file + cocok byte). |
| (sprint-b23, 2.33.0+110, run `38167132985` hijau) | **Sprint Batch 23 Net Worth** (bounded, approved piutang=aset): `networth.dart` murni + kartu ke-5 + `NetWorthScreen` (breakdown + tren walk-back estimasi + footnote) + 9 kunci `nw_*`. CI merah 3x (loadDebts import, const chart, case ganda) → hijau. Tanpa migration/dep. APK `SSR-SPACE-2.33.0-110-arm64.apk` (40.332.551 utuh). |
| (sprint-b24, 2.34.0+111, run `38169914332` hijau) | **Sprint Batch 24 Ringkasan Anggota** (bounded, approved; overlap audit: sharing/invite/peran/saldo/chip SUDAH ada, tanpa duplikasi): `family_summary.dart` murni + `FamilyScreen` (total + baris anggota + kick + invite) + ikon members + search + 6 kunci `fam_*`. TDD 6/6 lokal, langsung hijau. Tanpa migration/dep. APK `SSR-SPACE-2.34.0-111-arm64.apk` (40.332.611). |
| (batch-25, 2.35.0+112, run `38176247150` hijau) | **Batch 25 FINAL**: mic diagnostik (`vc_error_detail` + TDD format) — catatan: run fallback 38151517844 merah (3 fail, nama test tak sempat diagnosis) lalu fix zona 2c12a06 (lokal 8/8 incl. t8/t9) hijau; pelajaran: pantau tiap run sebelum pivot; polish ellipsis 4 tile; audit crash bersih. Tanpa migration/dep. APK `SSR-SPACE-2.35.0-112-arm64.apk` (40.332.715). Device: kode mic + mentah OCR. |
| (sprint-b26, 2.36.0+113, run `38185407438` hijau) | **Sprint Batch 26 Smart Insights revisi** (audit dulu: insight/budget-alert/transfer/PDF sudah ada — bangun delta saja): anomali + hari boros + tips menempel `weekly_insight` (aturan 3x+50rb, cap 3; kartu + 4 kunci `ins_*`; caller nol berubah). TDD 7/7 lokal, langsung hijau. Tanpa migration/dep. APK `SSR-SPACE-2.36.0-113-arm64.apk` (40.332.775). Next terpisah: reminder utang (butuh `DebtRecord.deadline` + jadwal). |
| (sprint-b27, 2.37.0+114, run `38188573742` hijau) | **Sprint Batch 27 Pengingat Jatuh Tempo** (bounded, approved H-3/H-1 jam 09:00): `dueDate?` + `due_reminder` murni (TDD 11/11 lokal) + `due_notify` (channel, ID stabil, hook main+mutasi) + `debt_store` pindah IO + upcoming 2 layar + editor deadline + 12 kunci `due_*`. CI merah 2x (API v22 named-only, vonis log) → hijau. Tanpa migration/dep. APK `SSR-SPACE-2.37.0-114-arm64.apk` (40.332.879 utuh). Pelajaran: baca pesan error sampai nama param (bukan cuma baris). |
| (batch-28, 2.38.0+115, run `38194861502` hijau) | **BATCH 28 Pencarian & Filter Transaksi** (bounded, approved client-side + caption jujur): `tx_filter.dart` murni + favorit prefs cap-10 + search/sheet/caption/strip + 21 kunci `txf_*`. TDD 12/12 lokal, langsung hijau. Tanpa migration/dep. APK `SSR-SPACE-2.38.0-115-arm64.apk` (40.464.131). Pelajaran: docs AGENTS/AUDIT batch ini tertinggal (dicatat susulan di commit batch 29). |
| (sprint-b29, 2.39.0+116, run `38197036249` hijau) | **Sprint Batch 29 Tantangan 30 Hari** (bounded, approved target-harian + milestone hari-hemat): `save30.dart` murni + store + notify (channel sendiri, harian 20:00) + `Save30Screen` + tile hub + link Arcade + badge ke-9 + wins→XP + 22 kunci. TDD 14/14 lokal. Tanpa migration/dep. APK `SSR-SPACE-2.39.0-116-arm64.apk`. |
| (batch-30, 2.40.0+117, run `38198459897` hijau) | **BATCH 30 FINAL Polish Rilis** (bounded, approved tanpa ikon/splash): parity ID/EN permanen (`stringTable` + test) + baca-ulang save30 (param mati, copy empty riwayat) + changelog 2.40. Ikon/splash bawaan ditunda jujur (butuh aset + device). Tanpa migration/dep. APK `SSR-SPACE-2.40.0-117-arm64.apk`. |
| (batch-31, 2.41.0+118, run `38210380350` hijau) | **BATCH 31 Major** (spec+plan, approved A-D): logo brand monogram + struk super detail + voice native rebuild + konsistensi empty art. 4 commit hijau berurutan. Pelajaran: vonis regex $ keliru (asal benar, keyword kurang); queries manifest = vonis root-cause voice lama. Tanpa migration. |
| (firebase-ai, 2.48.0+126, run `38349661916` hijau) | **Firebase AI Parser** (spec+plan, approved): ganti Zen HTTP (kunci manual) → Firebase AI Logic (firebase_ai 4.0.0/auth 6.6.0/core 4.14.0, model `gemini-3.5-flash` — 2.0-flash mati 2026-06-01; -http/-secure_storage) + plugin gradle 4.5.0 via CI + link Google→Firebase fail-open + settings kartu status + 2 kunci `ai_*`. CI merah 1x (ambiguous_import User/OAuthProvider firebase vs gotrue → hide) → hijau. TDD lokal 10/10 + review subagent (0 Critical, 1 fix denied-message). Tanpa migration. APK `SSR-SPACE-2.48.0-126-arm64.apk` (41.453.625). Prasyarat owner: Firebase console + secret google-services.json. Follow-up: App Check enforcement 2026-11-02. |
| (redesign-1, 2.61.0+164, run `38557239440` hijau) | **REDESIGN Batch 1 Design System Foundation** (approved owner 2026-10-14): `lib/theme/glass.dart` (GlassCard/GlassPanel/GlassChip, BackdropFilter blur) + `lib/theme/tokens.dart` (GlassSpace/GlassRadius/GlassDuration/GlassElevation/GlassColors) + `lib/widgets/premium/` (premium_card, premium_button dgn scale anim, premium_section_header). Dark Noir (0xFF000000) cukup gelap utk efek kaca. Tanpa ubah logika bisnis. APK `SSR-SPACE-2.61.0-164-arm64.apk`. |
