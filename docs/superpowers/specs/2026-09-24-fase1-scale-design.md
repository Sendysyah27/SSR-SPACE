# Fase 1 Scale — Foreground Service Auto-Track + Invite Workspace

Tanggal: 2026-09-24 · Status: disetujui user (brainstorming)
Roadmap konteks: multi-fase ke skala banyak user (Fase 1 fitur inti → Fase 2 hardening → Fase 3 scale ops → Fase 4 monetisasi).

## Latar belakang

AUDIT.md menandai dua item sebagai inti sebelum skala:

- **B3** — auto-track hanya hidup selama proses app hidup. App di-swipe = tracking berhenti, padahal janji produk "otomatis".
- **A5** — join workspace hanya `created_by` (self-insert). Buku kas bersama keluarga/tim butuh jalur undang.

Keputusan user: foreground service penuh (bukan opt-in), fase pertama = fitur inti, hardening menyusul.

## Scope

Masuk:
1. Foreground service yang menjaga isolate Dart hidup saat `track_master` ON.
2. Invite workspace via token (tabel + RPC + UI undang + UI join).

Keluar (roadmap fase berikutnya): rate limit auto-insert, audit log, error monitoring, backup DB, invite deep link `ssrspace://`, billing.

---

## Bagian 1 — Foreground service auto-track

### Masalah teknis

Plugin `notification_listener_service` mengirim event ke Dart via MethodChannel. `NotificationListenerService` system-side mungkin tetap hidup, tetapi isolate Dart mati saat app di-swipe → event hilang. Solusinya menghidupkan proses app, bukan service Android-nya.

### Pendekatan

Paket `flutter_foreground_task` (Dart-first) menjalankan proses app di foreground selama `track_master == true`. Android service type: `specialUse` (dengan justifikasi Play Store), bukan `mediaPlayback`.

### Alur

```
User aktifkan master toggle (Pelacakan otomatis)
  → NotifTrack.ensureListening()   (existing, tanpa ubah)
  → ForegroundTrack.start()        (baru)
      - startForegroundService + notif persist low-priority
        "SSR SPACE · Memantau transaksi" (tap → buka app)
      - ForegroundTask jalan → isolate Dart tetap hidup
      - event stream plugin → _onEvent (gate & parser TIDAK berubah)
User matikan master toggle / logout
  → ForegroundTrack.stop()
```

### File

| File | Aksi | Peran |
|------|------|-------|
| `lib/core/saas/foreground_track.dart` | baru | state machine start/stop, cek `track_master` + session |
| `lib/main.dart` | edit kecil | init foreground task handler saat boot |
| `lib/screens/notif_settings_screen.dart` | edit | baris status "Pemantauan latar aktif" + galat OEM |
| `pubspec.yaml` | edit | tambah `flutter_foreground_task` |
| `.github/workflows/apk.yml` | edit | inject izin + service declaration (pola inject `NotificationListenerService` yang sudah ada; `android/` tetap tidak di-commit) |

### Izin Android (CI-inject)

- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS` (Android 13+)
- `<service android:foregroundServiceType="specialUse" ...>` + `PROPERTY_FOREGROUND_SERVICE_SPECIAL_USE` justification text

### Batas sadar (by design)

- OEM agresif (Xiaomi/Huawei) masih bisa kill service → UI tampilkan status jujur memakai `isServiceConnected()` yang sudah ada; jangan janji "selalu aktif".
- Battery optimization prompt tidak dipaksa; opsional di settings.
- Parser, gate `_onEvent`, dedup hash, `TransactionService.add`: nol perubahan.

### Test

- `test/foreground_track_test.dart`: start hanya bila master ON + session aktif + platform Android; stop saat master OFF/logout.
- CI `flutter build apk --release` wajib hijau (lesson `4693c88`).

---

## Bagian 2 — Invite workspace

### Masalah

Policy `join own org` (migration_07) hanya menerima self-insert bila `created_by = auth.uid()` → hanya pembuat yang bisa join. Butuh jalur undang untuk anggota lain.

### Pendekatan

Tabel `org_invites` (token hash) + RPC `join_org_by_invite`. Additive — tidak menyentuh policy `org_members` yang sudah rapat.

### Schema — `supabase/migration_10_org_invites.sql`

```sql
create table org_invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  role text not null default 'member' check (role in ('member','admin')),
  token_hash text not null unique,      -- sha256(token); token asli hanya dikirim sekali
  created_by uuid not null,             -- = auth.uid() pembuat
  expires_at timestamptz not null,      -- default now() + 7 hari
  max_uses int not null default 1,
  used_count int not null default 0,
  revoked boolean not null default false
);
```

### RLS (wajib patuh aturan anti-recursion AGENTS.md)

- SELECT: `is_org_admin(org_id)` — helper SECURITY DEFINER, **bukan** subquery ke `org_members`.
- INSERT: `is_org_admin(org_id)` + `with check (created_by = auth.uid())`.
- UPDATE/DELETE (revoke): `is_org_admin(org_id)`.
- Client tidak pernah baca row invite by token → join lewat RPC.

### RPC `join_org_by_invite(p_token text)` — SECURITY DEFINER

```
1. hash = sha256(p_token)
2. select invite where token_hash = hash
   → tidak ada / revoked / expired / used_count >= max_uses
     → raise dengan kode jelas: INVITE_INVALID | INVITE_EXPIRED | INVITE_EXHAUSTED
3. Sudah member org itu? → return 'ALREADY_MEMBER' (idempotent)
4. insert org_members (org_id, user_id = auth.uid(), role dari invite)
5. update org_invites set used_count = used_count + 1
6. return org_id
```

Keamanan: token asli tidak pernah masuk DB (hanya hash), default sekali pakai, expiry 7 hari, authz dari JWT login bukan input client.

### File

| File | Aksi | Peran |
|------|------|-------|
| `supabase/migration_10_org_invites.sql` | baru | tabel + RLS + RPC |
| `lib/core/saas/invite_service.dart` | baru | create/list/revoke/join (wrap RPC) |
| `lib/screens/invite_screen.dart` | baru | daftar invite aktif (masked), buat undangan (role member/admin), salin kode, revoke |
| `lib/screens/org_switcher_screen.dart` | edit kecil | tab "Punya kode undangan?" → tempel kode → join → refresh daftar workspace |
| `test/invite_token_test.dart` | baru | hash token, masking, logika expiry murni |

### UX

- Lainnya → Undang anggota → `invite_screen.dart`.
- Format tautan yang disalin: `ssrspace://invite/<token>` (opsional, deep link intent-filter TIDAK di fase ini) + kode token mentah untuk paste manual.
- Join: Org switcher → "Punya kode undangan?" → input kode → `join_org_by_invite` → refresh workspace list.
- Gate lama (`created_by` self-join) tetap jalan → backward compatible.

### Test & verifikasi

- Unit: `test/invite_token_test.dart` (hash, masking, expiry).
- Unit: mock RPC untuk flow join (valid / expired / revoked / sudah member).
- SQL invalid/expired/revoke → raise: verifikasi via checklist manual Supabase (konsisten dengan pola audit; lokal tidak ada local stack).

---

## Urutan implementasi

1. **Invite (independen, duluan):** migration_10 → `invite_service.dart` → `invite_screen.dart` → edit `org_switcher_screen.dart` → test → ingatkan user jalankan migration di Supabase Dashboard.
2. **Foreground service:** pubspec → `foreground_track.dart` → edit `main.dart` + `notif_settings_screen.dart` → workflow CI inject izin → test.
3. **Verify + delivery:** commit terpisah per langkah → push → `gh run watch` sampai hijau (**build APK wajib hijau, test hijau saja tidak cukup**) → download APK ke `/sdcard/Download/SSR-SPACE/` → update `AUDIT.md` (A5 & B3 done + checklist device) → update `AGENTS.md` bila ada aturan baru.

## Error handling

- Join gagal → pesan spesifik dari RPC (`INVITE_INVALID` / `INVITE_EXPIRED` / `INVITE_EXHAUSTED` / `ALREADY_MEMBER`), bukan error generik.
- Foreground service diblokir OEM → status jujur di UI, tanpa fallback diam-diam.
- Semua insert transaksi tetap lewat `TransactionService.add` existing (insert → mint → update).

## Risiko

| Risiko | Mitigasi |
|--------|----------|
| Play Store tolak `specialUse` | Teks justifikasi: service agar pencatatan notifikasi keuangan berjalan di background |
| Isolate lama mati → stream mati | `ensureListening(force: true)` on resume (existing); foreground task bikin isolate jarang mati |
| Token invite bocor via screenshot | Token asli sekali di UI, DB simpan hash, expiry 7 hari + revoke |
| OEM kill walau foreground | Status jujur via `isServiceConnected()`; checklist device termasuk cek OEM |

## Testing summary

| Test | Menutup |
|------|---------|
| `test/foreground_track_test.dart` | gate start/stop service |
| `test/invite_token_test.dart` | hash, masking, expiry |
| CI `flutter build apk --release` | API Android/Flutter yang tak tersentuh test (lesson `4693c88`) |
| Checklist manual device (AUDIT.md) | foreground aktif, notif persist, join invite end-to-end |
