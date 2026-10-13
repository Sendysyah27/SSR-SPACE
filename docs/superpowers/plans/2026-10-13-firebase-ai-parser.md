# Firebase AI Parser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ganti AI fallback Zen (kunci manual) dengan Firebase AI Logic (aktif otomatis saat login Google), hybrid rule-dulu tetap.

**Architecture:** Service baru `firebase_ai_parser.dart` dengan generate-fn terinjeksi (TDD tanpa jaringan); linking Firebase di `AuthService` fail-open; config native hanya via step inject `apk.yml` karena `android/` tak di-commit.

**Tech Stack:** `firebase_core`, `firebase_auth`, `firebase_ai` (pin saat Task 1); `gemini-2.0-flash` (verifikasi nama saat Task 3, fallback model stabil bila berubah).

**Spec:** `docs/superpowers/specs/2026-10-13-firebase-ai-parser-design.md`

## Global Constraints

- `flutter` tak ada di Termux — analyze/test hanya via CI (`git push origin main` → `gh run watch`).
- Version wajib naik tiap push kode (Skema A): `pubspec.yaml` + `lib/utils/app_info.dart` identik + entri `assets/changelog_id.md`.
- Prasyarat manual user SEBELUM Task 2 berguna: Firebase console → app Android `com.ssr.space.ssr_space` (+ SHA-1) → `google-services.json` → secret `SSR_GOOGLE_SERVICES_JSON` → aktifkan AI Logic/Gemini API.
- Tanpa migration, tanpa commit folder `android/`, fail-open di semua titik Firebase (app tetap jalan tanpa AI).
- Copy UI Indonesia, tambah kunci ID+EN (parity test `strings_parity_test.dart` harus hijau).

## Review Focus

- OCR kosong/whitespace → `parseReceiptFirebase` return null tanpa panggil model (hemat quota).
- Model jawab non-JSON/sampah → null via `parseAiDraft` existing (jangan throw baru).
- Firebase belum init (tanpa google-services.json) → factory return null, sheet diam (tanpa error).
- User email-only (Firebase user null) → status jujur `ai_need_google`, bukan `ai_fail` samar.
- Quota habis / 403 / API mati → `AiFailure('denied'|'server')`, sheet tampil pesan jujur, manual tetap bisa.

---

### Task 1: Swap dependensi pubspec

**Files:**
- Modify: `pubspec.yaml:42-48`
- Test: CI `flutter pub get` (step existing)

**Interfaces:**
- Consumes: —
- Produces: `firebase_core`, `firebase_auth`, `firebase_ai` tersedia; `http`, `flutter_secure_storage` hilang.

- [ ] **Step 1: Cek versi stabil terbaru** `firebase_core`, `firebase_auth`, `firebase_ai` di pub.dev (catat versi exact yang dipilih).
- [ ] **Step 2: Edit `pubspec.yaml`** — tambah 3 firebase (komentar: AI parser struk), hapus blok `http` + `flutter_secure_storage` (baris 42-44).
- [ ] **Step 3: Verifikasi lokal** — `grep -r "package:http\|flutter_secure_storage" lib/ test/` harus NOL kecuali file yang dihapus Task 4.
- [ ] **Step 4: Commit** — `git add pubspec.yaml && git commit -m "chore: swap zen deps to firebase ai"` (JANGAN push sendiri; push digabung Task 9).

### Task 2: CI inject plugin google-services

**Files:**
- Modify: `.github/workflows/apk.yml` (step baru SETELAH step `Tulis google-services.json bila secret ada`, ~baris 331-340)

**Interfaces:**
- Consumes: secret `SSR_GOOGLE_SERVICES_JSON` (existing)
- Produces: build dengan Firebase terinisialisasi; assert merah bila wiring gagal.

- [ ] **Step 1: Tulis step python** mengikuti pola step lain: bila `android/app/google-services.json` ada → tambah classpath `com.google.gms:google-services` ke root gradle + `apply plugin` ke app gradle (tangani KTS dan Groovy dua template seperti step minSdk); bila file tak ada → lewati dengan echo jujur (fallback lama).
- [ ] **Step 2: Tambah assert keras** — file json ada ⇒ plugin string ada di kedua gradle; gagal = `SystemExit(1)`.
- [ ] **Step 3: Verifikasi** — `python3 -m py_compile` tak berlaku (embedded); cek indent YAML manual via `read`; hijau final = CI Task 9.
- [ ] **Step 4: Commit** — `git add .github/workflows/apk.yml && git commit -m "ci: inject google-services gradle plugin"`.

### Task 3: Service FirebaseAiParser (TDD)

**Files:**
- Create: `lib/services/firebase_ai_parser.dart`
- Test: `test/firebase_ai_parser_test.dart`

**Interfaces:**
- Consumes: `aiReceiptPrompt(String)` + `parseAiDraft(String)` dari `lib/services/ai_draft.dart`; `AiFailure` dipindah dari `ai_client.dart` ke sini (atau file error kecil — putuskan sekali, catat).
- Produces:
  - `typedef AiGenerate = Future<String?> Function(String prompt);`
  - `Future<AiDraft?> parseReceiptFirebase({required String ocrText, required AiGenerate generate})` — null bila ocr kosong; timeout 30 dtk + retry 1x (timeout/network/5xx); `AiFailure('denied')` bila generate lempar `AiDenied`.
  - `class AiDenied implements Exception` — penanda 403/quota/belum-login dari factory.
  - `Future<AiGenerate?> firebaseAiGenerate()` — null bila Firebase tak init / user null (try/catch, tak pernah throw).

- [ ] **Step 1: Tulis test gagal** `test/firebase_ai_parser_test.dart`: sukses JSON → draft; ocr kosong → null tanpa panggil generate (hitung panggilan); generate throw TimeoutException 2x → `AiFailure('timeout')`; `AiDenied` → `AiFailure('denied')`; teks sampah → null.
- [ ] **Step 2: Jalankan via `dart --enable-asserts`** (pola repo untuk logika murni) — harus FAIL (file belum ada).
- [ ] **Step 3: Implementasi** `firebase_ai_parser.dart`: prompt via `aiReceiptPrompt` (cap 4000 existing), kirim via `generate`, parse via `parseAiDraft`; factory `firebaseAiGenerate()` bangun `FirebaseAI.googleAI().generativeModel(model: 'gemini-2.0-flash')` dalam try/catch → null bila apa pun gagal.
- [ ] **Step 4: Verifikasi lokal** — `dart --enable-asserts` semua test baru + `test/ai_draft_test.dart` lama hijau.
- [ ] **Step 5: Commit** — `git add lib/services/firebase_ai_parser.dart test/firebase_ai_parser_test.dart && git commit -m "feat: firebase ai receipt parser (tdd)"`.

### Task 4: Hapus jalur Zen

**Files:**
- Delete: `lib/services/ai_client.dart`, `lib/services/ai_key_store.dart`

**Interfaces:**
- Consumes: `AiFailure` pindah ke Task 3 (jangan duplikat).
- Produces: nol referensi `ai_client`/`ai_key_store` di `lib/`, `test/`.

- [ ] **Step 1: Hapus dua file.**
- [ ] **Step 2: Grep** `ai_client|ai_key_store|readAiKey|readAiOn|parseReceiptAi` di `lib/ test/` — harus NOL (selain spec/plan docs).
- [ ] **Step 3: Commit** — `git add -A && git commit -m "chore: drop zen ai client + keystore"`.

### Task 5: Init Firebase + auth linking (fail-open)

**Files:**
- Modify: `lib/main.dart:23-27`, `lib/services/auth_service.dart:56-88`

**Interfaces:**
- Consumes: `firebaseAiGenerate()` (Task 3, untuk cek tak langsung)
- Produces: sesi Firebase mengikuti login Google; Supabase tetap sumber kebenaran.

- [ ] **Step 1: `main()`** — setelah `ensureInitialized`, `try { await Firebase.initializeApp(); } catch (e) { debugPrint(...) }` SEBELUM `SupabaseConfig.init()`. Komentar: gagal = AI mati, app jalan.
- [ ] **Step 2: `signInWithGoogle()`** — setelah `signInWithIdToken` sukses, tambah try/catch: `await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken, accessToken: gauth.accessToken))`; gagal → `debugPrint` + lanjut (return tetap `res.session != null`).
- [ ] **Step 3: `signOut()`** — tambah `try { await FirebaseAuth.instance.signOut(); } catch (_) {}` sebelum/setelah Supabase signOut.
- [ ] **Step 4: Verifikasi** — tak ada unit test (butuh platform); cek `read` ulang diff + andalkan `flutter analyze` di CI Task 9.
- [ ] **Step 5: Commit** — `git add lib/main.dart lib/services/auth_service.dart && git commit -m "feat: link google sign-in to firebase auth (fail-open)"`.

### Task 6: Sheet pakai Firebase (hybrid tetap)

**Files:**
- Modify: `lib/widgets/tx_input_sheet.dart:11-13` (import), `:542-573` (`_tryAiDraft`)

**Interfaces:**
- Consumes: `parseReceiptFirebase`, `firebaseAiGenerate`, `AiFailure` (Task 3)
- Produces: perilaku scan §`_pickScanSource` tak berubah (trigger `!confident || inconsistent` tetap).

- [ ] **Step 1: Ganti import** `ai_client`/`ai_key_store` → `firebase_ai_parser`.
- [ ] **Step 2: Tulis ulang `_tryAiDraft`** — `final gen = await firebaseAiGenerate(); if (!mounted || gen == null) return null;` lalu `parseReceiptFirebase(ocrText: raw, generate: gen)`; mapping error: `denied` → `tr('ai_need_google')`, lain → `tr('ai_fail')`; `_scanning`/`ai_working` flow tetap.
- [ ] **Step 3: Verifikasi** — `read` diff; test widget tak ada (pola repo); CI Task 9.
- [ ] **Step 4: Commit** — `git add lib/widgets/tx_input_sheet.dart && git commit -m "feat: sheet ai fallback via firebase"`.

### Task 7: Settings kartu status + strings

**Files:**
- Modify: `lib/screens/lainnya/settings_screen.dart:3,178,954-1088` (`_AiCard`), `lib/utils/strings.dart:2283-2311`

**Interfaces:**
- Consumes: `firebaseAiGenerate()` (cek status, tanpa kunci)
- Produces: kartu tanpa TextField; subtitle jujur per status.

- [ ] **Step 1: Tulis ulang `_AiCard`** — hapus `_keyC`, `_hasKey`, `_save/_clear/_keyReady`; `_refresh()` cek `firebaseAiGenerate() != null` → subtitle `ai_active` + toggle ON dimungkinkan, else `ai_need_google` + tombol ke auth (atau teks saja — pilih sekali, konsisten). Toggle ON tanpa Firebase → pesan `ai_need_google`, tetap OFF.
- [ ] **Step 2: Strings** — hapus `ai_where/ai_key_hint/ai_save/ai_clear/ai_saved/ai_cleared/ai_need_key/ai_bad_key`; tambah `ai_need_google` (`Masuk dengan Google untuk menyalakan AI.` / `Sign in with Google to enable AI.`) + `ai_active` (`AI aktif via login Google.` / `AI active via Google sign-in.`). Kunci review-screen (`ai_retry/ai_review_t/ai_use/ai_discard/ai_merchant/ai_date/ai_items/ai_add_item/ai_payment/ai_tax`) + `ai_title/ai_sub/ai_enable/ai_working/ai_fail` TETAP.
- [ ] **Step 3: Verifikasi** — parity test hijau (CI); `grep ai_key_store lib/` NOL.
- [ ] **Step 4: Commit** — `git add lib/screens/lainnya/settings_screen.dart lib/utils/strings.dart && git commit -m "feat: settings ai status, drop key input"`.

### Task 8: Bump + changelog (Skema A)

**Files:**
- Modify: `pubspec.yaml` (version), `lib/utils/app_info.dart` (`AppInfo.version`), `assets/changelog_id.md`

**Interfaces:**
- Consumes: semua task di atas.
- Produces: versi baru identik di 2 file + entri changelog paling atas.

- [ ] **Step 1: Naikkan minor** (perilaku baru): baca versi kini di `pubspec.yaml`, bump sesuai Skema A.
- [ ] **Step 2: Samakan `AppInfo.version` + tambah entri changelog** (`Yang baru di X.Y.Z`: AI tanpa kunci, syarat login Google).
- [ ] **Step 3: Commit** — `git add pubspec.yaml lib/utils/app_info.dart assets/changelog_id.md && git commit -m "chore: bump <v> + changelog"`.

### Task 9: Push + CI + APK (verifikasi akhir)

- [ ] **Step 1: Review diff** — `git log --oneline -8 && git status` (8 commit Tasks 1-8, tanpa file android/).
- [ ] **Step 2: Push** — `git push origin main` (satu push untuk hemat run CI).
- [ ] **Step 3: Pantau** — `gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status` hingga hijau (analyze 0 issue + test).
- [ ] **Step 4: Unduh APK berpola** — `gh release download ci-apk -p "SSR-SPACE-<v}-arm64.apk" -D /sdcard/Download/SSR-SPACE/ --clobber`, verifikasi ukuran wajar (~40M).
- [ ] **Step 5: Catat lokal** — `AGENTS.md` + `AUDIT.md` §7 (tanpa commit sendiri; ikut push berikutnya).
