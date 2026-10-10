# SPRINT AUDIT — SSR SPACE (Task 1, Sprint 4 Hari)

Tanggal: 2026-10-10 · Versi audit: `2.13.7+84` (`e317a01`) · CI: hijau
Sifat: audit baca-kode saja, tanpa perubahan perilaku. Sumber: `lib/` (138 file),
`supabase/` (schema + 15 migration), `test/` (66 file), `.github/workflows/` (3 file).

---

## 1. Inventaris fitur + status

Legenda: ✅ jalan (CI hijau + dipakai) · ⚠️ jalan tapi rapuh/batasan sadar ·
❌ rusak/disable · 🔲 belum ada (baru stub/kuota/UI tanpa backend).

### 1.1 Auth, sesi, onboarding
| Fitur | Status | Catatan |
|---|---|---|
| Auth email/password Supabase + verifikasi email | ✅ | `auth_service.dart` tipis; tanpa OAuth, **tanpa lupa/reset password** |
| Intro consent 4 halaman + theme step | ✅ | Gate prefs `consent_v1`, user lama lihat sekali |
| PIN lokal (SHA-256+salt, lockout 5x→60s, auto-lock 1–30 mnt) | ✅ | PIN = device-only (`session_service.dart`); hapus data app = PIN hilang, data cloud aman |
| Ganti PIN (PIN lama / magic-link cadangan) | ✅ | Deep-link `app_links`, butuh redirect URL di Dashboard |
| Splash boot + error offline + retry | ✅ | Ada `_SplashError`; tanpa internet = mentok splash |

### 1.2 Workspace / multi-user
| Fitur | Status | Catatan |
|---|---|---|
| Buat/ganti workspace, active org di prefs | ✅ | |
| Invite via token hash + RPC `join_org_by_invite` | ✅ | Hash-only, idempoten, max-uses; RLS test T09 |
| Peran owner/admin/member, kick, hapus workspace | ✅ | `migration_14`, RPC + PIN-gate |
| Mode We Space Bebas/Bendahara + layar Aktivitas | ✅ | `migration_15`, RLS test T16–T20 |
| Badge pencatat di TxRow | ✅ | `created_by` saja, tanpa nama (privacy by design) |

### 1.3 Dompet & transaksi
| Fitur | Status | Catatan |
|---|---|---|
| CRUD dompet, tipe cash/ewallet/bank + tipe client-only Liquid/Savings/Investments | ✅ | Rename/type tanpa PIN; hapus PIN-gate kecuali isi |
| Saldo terhitung (`wallet_balance`) | ✅ | Transfer dihitung, null-wallet tidak |
| Input via sheet wizard 2 langkah + numpad custom + ketik-cepat lokal | ✅ | Validasi per-field; tanggal+jam custom tanpa migration |
| Edit/hapus transaksi, transfer auto-merge (out+in auto ≤10 mnt) | ✅ | Histori lama tak diubah |
| Kode `TX-000001` via RPC `mint_tx_code` | ✅ | Insert-dulu-mint-kemudian (tak bakar nomor) |
| Riwayat per dompet, grup per-hari, virtualisasi sliver | ✅ | **Limit query 100/200 baris** — data lama tak terlihat (§4) |
| Transfer detect suggest-only | ✅ | |

### 1.4 Auto-track notifikasi (fitur pembeda)
| Fitur | Status | Catatan |
|---|---|---|
| Listener 17 bank/e-wallet + parser Rp + klasifikasi in/out | ✅ | BigText fallback via patch CI; QRIS-merchant pending ditahan |
| Foreground service `specialUse` + master switch | ✅ | OEM agresif tetap bisa kill |
| Mapping dompet per app + kategori instan + guard tanpa-dompet | ✅ | Fail-open: `st_need_wallet`, Simpan manual tetap bisa |
| Rate limit 10 auto-insert/60s/org (server) | ✅ | Trigger `migration_11`, RLS test T06 |
| Notif "tersimpan" heads-up + sheet detail | ✅ | `AutoSavedNotify`, tanpa overlay (overlay dihapus 2.5.0) |

### 1.5 Budget, laporan, ekspor
| Fitur | Status | Catatan |
|---|---|---|
| Budget/kategori/bulan + pace + ring + alert real-time + `warn_pct` | ✅ | Trigger `migration_16`; butuh migration dijalankan user |
| Laporan: donut 3 iris, Top-N+susunan, banding bulan, filter dompet | ✅ | Ekspor ikut filter |
| Ekspor CSV + PDF premium (Pro) + simpan Documents + notif Bagikan | ✅ | PDF gate kuota client-side |
| Impor CSV tempel-teks + pratinjau mapping | ✅ | Round-trip diperbaiki 2.4.4 |

### 1.6 Engagement (LOOP 1–4) & pengingat
| Fitur | Status | Catatan |
|---|---|---|
| Streak, health score, pace, calm-streak, insight mingguan, nudge | ✅ | Offline-first, hitung lokal |
| Goals + forecast + dana darurat | ✅ | Prefs, bukan transaksi |
| Badge/tantangan/level + Arcade | ✅ | XP deterministik |
| Pengingat harian+mingguan + heads-up (2.13.7) | ✅ | Startup silent; izin hanya saat toggle |
| Widget hari ini + QS tile | ⚠️ | Snapshot prefs jalan; **trigger native DISABLE sementara** (FC 2.13.1) |
| Scan struk ML Kit + dialog OCR mentah | ✅ | APK +12MB model; ProGuard keep-rules di CI |

### 1.7 NFC, billing, settings
| Fitur | Status | Catatan |
|---|---|---|
| NFC e-money read-only + taut dompet + selisih dua arah | ✅ | Hanya Mandiri terbukti device; minSdk 26 |
| Billing/kuota Gratis vs Pro | 🔲 | **Lihat §3.3** — kuota jalan, pembayaran belum |
| Settings (ID/EN, kurs+cache, font, tema, search, bantuan, tentang) | ✅ | |
| Privacy mode samarkan nominal | ✅ | Global via notifier |
| Backup 3 CSV + impor + error reporter in-house | ✅ | Tanpa auto-backup selain pg_dump mingguan CI |

---

## 2. Tech debt & bug yang diketahui

### 2.1 Bug terbuka (dari backlog AUDIT/AGENTS)
1. `invite_screen.dart:294,317` — `DateTime.parse` tanpa guard bila `expires_at`/`created_at` null → crash potensial (diakui backlog).
2. `dashboard_service.dart` — **yatim**: ada di `lib/` + test, nol importir. Hapus atau pakai.
3. Widget native tak auto-refresh (follow-up 2.13.7) — snapshot prefs ditulis, provider diam.
4. Flazz/TapCash/JakCard belum terbukti device (best-effort).
5. Legenda 3 kolom sempit di 360dp; banner limit mencakup target tabungan (kosmetik).

### 2.2 Tech debt struktural
1. **Tanpa DB lokal sama sekali** (sqflite dilepas; grep bersih). Offline = baca pun mati; semua layar = query remote tiap buka tab. Menambah cache/Sync = proyek besar.
2. **Limit query keras** (`list` 100, `listMonth`/`listByWallet` 200) tanpa pagination/infinite scroll. User aktif >200 tx/bulan kehilangan data di UI + rekap.
3. **Beranda 1494 baris, OtherScreen 1126 baris** — God-screen; tiap resume me-reload 4 tab + 12-bulan histori (boros egress).
4. **CI merakit `android/` dari nol** (±10 step inject Python: izin, listener, widget, QS tile, NFC, ML Kit rules, signing). Rapuh terhadap bump AGP/Flutter; satu template berubah = build merah misterius.
5. **Kuota plan ditegakkan client-side saja** (`plan_limits.dart`, fail-open saat error). Tanpa RLS/fungsi server = bypass via API langsung.
6. **34+ kunci prefs datar** di `SharedPreferences` tanpa skema/migrasi versi — tabrakan nama & korupsi parsial sulit dilacak.
7. **Notif permission + exact-alarm** masih sensitif OEM (MIUI menelan overlay, heads-up fix 2.13.6). Lapisan ini sumber FC berulang (2.13.1–2.13.5).
8. RLS test (T01–T25) bagus, tapi **`migration_13` (retention pg_cron) tak teruji CI** — diverifikasi manual; drift diam-diam mungkin.
9. Supabase project **free-tier pause 7 hari inaktif** (backlog D8 heartbeat belum dikerjakan) — risiko mati total saat sepi.
10. `organizations.plan` dibaca per layar tanpa cache — N+1 query tiap navigasi.

---

## 3. Arsitektur data

### 3.1 Prinsip: cloud-first, device = cache pengaturan
- **Supabase Postgres + RLS** = satu-satunya sumber data bisnis. **Nol tabel lokal.**
- `SharedPreferences` = pengaturan + state UI (locale, mask, reminder, widget snapshot, game seen, dsb).
- `flutter_secure_storage` = **nol pakai di `lib/`** (grep bersih): PIN hash di prefs biasa. Klaim "aman" lemah + dep mati membebani APK.

### 3.2 Skema (10 tabel + 2 helper)
| Tabel | Isi | RLS inti |
|---|---|---|
| `organizations` (+`plan`, +`space_mode`) | workspace | member-read; create bila `created_by=self` |
| `org_members` (`role` owner/admin/member) | keanggotaan | tanpa self-subquery (anti-recursion 08); admin via `is_org_admin` DEFINER |
| `wallets` | dompet | member org |
| `transactions` (+`wallet_id/to_wallet_id`, `code`, `source_package/hash`, `created_by`) | mutasi | member org; auto-insert rate-limit 10/60s |
| `budgets` (+`warn_pct`) | limit/bulan | member org |
| `tx_sequences` | counter kode TX | deny direct, via RPC member-only |
| `subscriptions` (`pending`) | niat upgrade | — |
| `org_invites` (hash saja) | undangan | admin-only read, join via RPC |
| `audit_logs` (180 hari) | jejak server | no client write |
| `client_errors` (30 hari) | error app | milik sendiri |
| `budget_alerts` | sirene budget | member-read |
| View/fungsi: `wallet_balance`, `mint_tx_code`, `join_org_by_invite`, `set_space_mode`, `can_write_space`, `is_org_creator`, trigger `check_budget_alert` + `tx_manual_insert` | | |

### 3.3 Uang & monetisasi: BELUM jalan ujung-ke-ujung
- Alur hari ini: Billing → `_upgrade()` → **insert satu baris `pending`** → selesai. Tak ada pemanggil `create-snap`, tak ada Snap UI, tak ada webhook, tak ada yang mengubah `plan`→`pro`.
- Edge function `create-snap` ada (butuh deploy manual + secret Midtrans) tapi yatim.
- Artinya: **Pro tak bisa dibeli; kuota Gratis hanya persuasi UI.** Ini penghambat scale #1 dari sisi bisnis.

### 3.4 Observabilitas & backup
- `ErrorReporter` in-house (dedupe 60 mnt, cap 20/jam, tanpa PII) → `client_errors`.
- Backup: pg_dump mingguan CI (butuh secret `SUPABASE_DB_URL`) + ekspor CSV manual user.
- RLS CI (`rls-test.yml`) jalan tiap push `supabase/**` — aset terkuat repo ini.

---

## 4. Penghambat scale ke banyak user

### 4.1 Auth & keamanan (P0)
1. **Tanpa reset password** — user lupa = terkunci permanen (support manual via Dashboard). Wajib sebelum promosi.
2. Tanpa OAuth (Google) — friksi daftar di Indonesia tinggi.
3. PIN device-only + **tanpa biometrik (`local_auth` nol pakai di `lib/`, dep mati)** — ganti HP = setup ulang.
4. Anon key tertanam di APK (wajar) tapi **kuota tanpa penegakan server** → satu user nakal bisa spam insert (rate limit hanya auto-insert, manual bebas).

### 4.2 Multi-user & onboarding (P0)
1. **Onboarding auto-track tak terpandu**: user baru harus (a) beri izin listener, (b) nyalakan master, (c) petakan tiap bank ke dompet — tanpa wizard, tanpa penjelasan. Fitur pembeda = paling susah dinyalakan.
2. Invite butuh app terinstal + login + buka kode manual; tanpa deep-link undangan → drop-off.
3. Tanpa peran read-only/auditor; `created_by` anonim (tanpa nama) bikin workspace ramai membingungkan.
4. Konflik tulis (dua orang edit budget/tx sama) = last-write-wins diam-diam.

### 4.3 Kapasitas & biaya (P1)
1. Pola "reload semua tiap tab/resume" + tanpa pagination = **egress membengkak per user aktif**; free 5GB bisa jebol oleh puluhan user berat.
2. Free-tier pause 7 hari (D8 belum) = mimpi buruk reputasi saat traction naik-turun.
3. `autoUsedThisMonth` tanpa limit (select id sebulan penuh) + rekap 12 bulan di Beranda = query berat yang tumbuh dengan data.
4. Tanpa realtime (polling saat resume) — kolaborasi terasa basi; realtime Supabase = biaya + kompleksitas.

### 4.4 Operasional (P1)
1. Migration dijalankan **manual oleh user via Dashboard** (15 file berurutan!) — onboarding backend rapuh; satu langkah kelewat = fitur mati diam-diam. Butuh squashed baseline + cek versi skema saat boot.
2. CI Android-rakitan rentan; tanpa device farm — verifikasi = HP user.
3. Tanpa analitik adopsi (mana fitur dipakai?) — keputusan produk = tebakan.
4. Play Store listing, policy privasi in-app (dialog ada, hosting belum?), DPA — belum diaudit.

### 4.5 Rekomendasi urutan (untuk Task 2+)
1. Reset password + perbaikan invite (guard `DateTime.parse`) — murah, P0.
2. Penegakan kuota server-side (RPC/fungsi) + putuskan nasib billing (cabut klaim Pro atau sambung Midtrans penuh).
3. Pagination + cache baca + kurangi reload Beranda (selamatkan egress).
4. Wizard auto-track 3 langkah + heartbeat anti-pause (D8).
5. Squash migration + cek skema saat boot.

---
*Audit oleh agent (baca-kode). Status "✅" = ada kode + test/CI hijau; kebenaran di device ikut verifikasi user.*
