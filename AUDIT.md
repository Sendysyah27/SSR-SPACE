# AUDIT.md — SSR SPACE

Audit keamanan & kualitas fitur **auto-track notifikasi bank / dompet digital**.  
Tanggal audit: **2026-09-24** · Versi saat audit: 2.3.2+14 → dieksekusi sampai **2.3.3+15**.  
Lensa: OWASP / RLS Supabase / input hostile (isi notif pihak ketiga).

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

**Status CI setelah fix:** green · 19 tests · APK `ssr-space-apk` sukses.

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

---

### P3 — Terbuka (belum dikerjakan)

Lihat **Backlog** di bawah.

---

## 3. Pipeline auto-track (referensi kode)

```
lib/main.dart
  SupabaseConfig.init()
lib/screens/main_shell.dart:26
  NotifTrack.ensureListening()
lib/core/saas/notif_track_service.dart
  notificationsStream → _onEvent
lib/core/saas/notif_parse.dart
  matchWatchedApp / parseNotifAmount / classifyNotif / notifHash / ymd
lib/core/saas/transaction_service.dart
  add() → insert → mint_tx_code → update code
lib/screens/notif_settings_screen.dart
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
| A1 | **Edit transaksi** (wallet, kategori, tanggal, amount) | ✅ done `2.3.4+16` edit in-place + hapus berkonfirmasi (`transactions_screen`, `TransactionService.update`/`delete`) |
| A2 | **Saldo dompet** | ✅ done `2.3.4+16` view `wallet_balance` (`migration_09`, `security_invoker`); tampil di Dompet + dropdown form |
| A3 | **Rate limit auto-insert** | Mis. max N insert / menit / org (prefer: RPC insert terkontrol atau Supabase rate limit); status “Dibatasi” |
| A4 | **Audit log server** | Tabel `audit_logs(org_id, session/app, event, meta)` untuk insert otomatis & join org |
| A5 | **Invite workspace** | Ganti “self-join by created_by” menjadi token invite / approve owner; UX Lainnya → Undang anggota |
| A6 | **Verifikasi package Play Store** | Di device: catat `packageName` asli tiap bank di allowlist; perbaiki prefix yang meleset |

### Sprint B — Kualitas auto-track

| # | Item | Detail |
|---|------|--------|
| B1 | **Tanggal dari isi notif** | Regex `dd/MM/yyyy` / `yyyyMMdd` di title-content → `date` lebih akurat untuk scan ulang |
| B2 | **Ganti / fork plugin notif** | Plugin sekarang tanpa timestamp; eval `flutter_notification_listener` (ada `timestamp`) atau native |
| B3 | **Foreground service / boot receiver** | Tracking jalan walau app di background (izin + UX battery) — **keputusan product**: privacy vs “otomatis penuh” |
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

### Sprint D — Infra

| # | Item | Detail |
|---|------|--------|
| D1 | CI: `flutter analyze` step | Tangkap warning sebelum test |
| D2 | Setup-java v5 + checkout v5 | Hilangkan deprecation warning Actions |
| D3 | Pubspec description masih “offline multi-dompet” | Samakan dengan reality SaaS |
| D4 | Dependabot / pin actions by SHA | Supply chain |
| D5 | Backup export DB | CSV terjadwal / manual dari dashboard |

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

**Belum ada test:** RLS server-side (butuh local stack / testcontainers), pipeline `_onEvent` penuh.

---

## 7. Changelog audit → release

| Commit | Isi |
|--------|-----|
| `9634116` | P0 RLS+mint + P1 auto-track (wallet/date/allowlist/hash/insert-order) + tests + v2.3.3+15 |
| `1c401ef` | Fix prefix KEB Hana `id.co.bankbkemobile` (CI test merah) |
| `d4aec58` | **migration_08** fix RLS recursion “Gagal memuat dompet” |

APK artefak: run Actions hijau terakhir → artifact `ssr-space-apk`.

---

## 8. Cara baca doc ini

- **AGENTS.md** → cara kerja, workflow, aturan jangan-dilanggar.  
- **AUDIT.md** (ini) → kenapa kode begini, apa yang sudah / belum, urutan lanjutan.  
- Spec historis → `docs/superpowers/specs/2026-09-23-ssr-space-design.md` (baca bagian update).
