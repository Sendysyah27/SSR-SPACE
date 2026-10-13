# Spec: Firebase AI Logic untuk AI receipt parser

Tanggal: 2026-10-13. Status: draft, menunggu review user.
Tujuan: ganti AI fallback OpenCode Zen (butuh kunci API manual) dengan
Firebase AI Logic — AI aktif otomatis bila user login Google, tanpa
input kunci apa pun.

## 1. Pemahaman bersama

- Hasil yang diinginkan: scan struk tetap hybrid (rule-based dulu, AI
  fallback bila confidence rendah), tapi AI-nya via Firebase, bukan Zen.
- Untuk siapa: semua user yang login Google (mayoritas, karena auth
  utama = Google + email).
- Sukses: user login Google → AI parser jalan tanpa setting kunci;
  user belum login Google → diminta login (jujur, bukan error samar).
- Asumsi (koreksi bila salah): project Firebase boleh = project Google
  Cloud yang sudah dipakai untuk Google Sign-In; paket login email
  tetap didukung tapi tanpa AI.

## 2. Klasifikasi: architectural

Alasan: subsistem baru (Firebase Core + Auth + AI), config native via
CI inject, auth linking, service baru, perubahan UI Settings. Bukan
bounded karena tak ada alur Firebase di repo saat ini.

## 3. Pendekatan (2 opsi)

- A. Firebase AI Logic — Gemini via SDK resmi (direkomendasikan).
  Plus: tanpa kunci di app, quota per project, auth = sesi Firebase.
  Minus: butuh project Firebase + google-services.json + billing
  diaktifkan bila quota gratis terlampaui; user email-only tanpa AI.
- B. Pertahankan Zen + tambah opsi Firebase (ditolak).
  Alasan tolak: dua jalur = dua perawatan, UI kunci tetap ada,
  melanggar YAGNI.

## 4. Desain

### 4.1 Dependensi (pubspec)

- Tambah: `firebase_core`, `firebase_auth`, `firebase_ai`
  (versi di-pin saat implementasi, cek pub.dev terbaru yang stabil).
- Hapus: `http`, `flutter_secure_storage` — grep membuktikan keduanya
  hanya dipakai jalur Zen (`ai_client.dart`, `ai_key_store.dart`).
  Diet APK bonus, bukan tujuan utama.

### 4.2 Native + CI (pola existing, tanpa commit folder android/)

- `android/` tidak di-commit (di-generate CI). Semua config native
  = step inject baru di `apk.yml`, mengikuti pola yang sudah ada:
  - `google-services.json` sudah ditulis CI dari secret
    `SSR_GOOGLE_SERVICES_JSON` (step ada sejak Batch 4). Bila project
    Firebase = project yang sama, secret ini dipakai ulang; bila
    project beda, user supply file dari Firebase console.
  - Baru: apply plugin gradle `com.google.gms.google-services`
    (classpath + apply, KTS/Groovy dua template) + assert keras
    (gagal = merah di CI, bukan FC di device).
- Prasyarat manual user (tak bisa dilakukan agent): buat project di
  Firebase console → tambah app Android (package
  `com.ssr.space.ssr_space`, SHA-1 dari keystore) → download
  `google-services.json` → isi ke secret `SSR_GOOGLE_SERVICES_JSON`
  → aktifkan Firebase AI Logic / Gemini API.

### 4.3 Auth linking (fail-open)

- `main()`: `await Firebase.initializeApp()` sebelum Supabase init;
  gagal init = AI mati, app tetap jalan (jangan crash startup).
- `AuthService.signInWithGoogle()`: setelah idToken ditukar sesi
  Supabase (jalur existing tak berubah), tambah linking Firebase:
  `FirebaseAuth.instance.signInWithCredential(
  GoogleAuthProvider.credential(idToken, accessToken))`.
  Gagal linking → catat `debugPrint` + lanjut (Supabase = sumber
  kebenaran sesi; Firebase hanya untuk AI).
- Logout: `FirebaseAuth.instance.signOut()` berdampingan Supabase
  signOut, fail-silent.

### 4.4 Service baru: FirebaseAiParser

- File baru `lib/services/firebase_ai_parser.dart`:
  `FirebaseAI.googleAI().generativeModel(model: 'gemini-2.0-flash')`
  (nama model final = yang terverifikasi saat implementasi).
- Prompt = `aiReceiptPrompt(ocrText)` existing (dipakai ulang, tanpa
  duplikasi). Respons → `parseAiDraft()` existing (fail-open tetap).
- API: `parseReceiptFirebase({required String ocrText})` —
  tanpa apiKey. Timeout 30 dtk + retry 1x (semantik sama seperti Zen).
  Error jujur via `AiFailure` existing (`timeout|network|denied|
  server|empty`); `denied` = belum login Google.
- Hapus: `ai_client.dart`, `ai_key_store.dart`.

### 4.5 Pemanggil (hybrid tetap)

- `tx_input_sheet.dart` `_tryAiDraft`: ganti cek `readAiOn()/readAiKey()`
  dengan cek sesi Firebase (`FirebaseAuth.instance.currentUser != null`).
  Rule-based tetap utama; AI hanya bila rule tak confident
  (trigger existing tak berubah, termasuk mismatch sum!=total).
- `ai_draft.dart` + `ai_draft_screen.dart` + `test/ai_draft_test.dart`:
  tak tersentuh (format JSON/draft sama).

### 4.6 Settings UI

- Kartu AI di `settings_screen.dart` ditulis ulang: hapus TextField
  kunci + tombol simpan/hapus; ganti status:
  - Login Google + Firebase OK → "AI aktif" (toggle enable tetap ada,
    pindah ke prefs biasa bila masih diinginkan — keputusan saat plan).
  - Belum login Google → "Masuk dengan Google untuk menyalakan AI"
    + tombol ke layar auth.
- Strings: kunci `ai_key_hint/ai_save/ai_clear/ai_saved/ai_cleared/
  ai_need_key/ai_bad_key` dihapus; tambah `ai_need_google/ai_active`
  (ID+EN, parity test tetap hijau).

### 4.7 Testing

- TDD seperti biasa: logika murni (`ai_draft`, prompt) sudah ada test;
  service baru diuji dengan fake generative model (tanpa jaringan).
- Verifikasi akhir = CI hijau + scan struk device (user), karena
  `flutter` tak ada di Termux.

## 5. File yang disentuh

Ubah: `pubspec.yaml`, `lib/main.dart`,
`lib/services/auth_service.dart`, `lib/widgets/tx_input_sheet.dart`,
`lib/screens/lainnya/settings_screen.dart`, `lib/utils/strings.dart`,
`.github/workflows/apk.yml` (step plugin google-services),
`assets/changelog_id.md` (wajib tiap bump).
Baru: `lib/services/firebase_ai_parser.dart` (+ test).
Hapus: `lib/services/ai_client.dart`, `lib/services/ai_key_store.dart`.
Tanpa migration, tanpa dep native selain plugin google-services.

## 6. Risiko jujur

- User email-only kehilangan AI (bukan regresi fungsional inti;
  rule-based tetap jalan). Alternatif: Firebase email-link juga
  di-link ke Firebase Auth — diputuskan saat plan.
- Quota/billing Gemini: gratis ada batas; bila habis → `ai_fail`
  jujur, bukan crash. Monitoring via `client_errors` existing.
- `firebase_ai` versi/model bisa berubah; pin + verifikasi saat
  implementasi, bukan spekulasi di spec ini.

## 7. Urutan eksekusi (ringkas, detail di plan)

1. User: Firebase console + secret `SSR_GOOGLE_SERVICES_JSON`.
2. pubspec (tambah 3 firebase, hapus http/secure_storage).
3. CI inject plugin google-services + assert.
4. `main()` init + auth linking + logout.
5. `firebase_ai_parser.dart` + test.
6. Sheet + settings + strings + changelog + bump version.
7. Push → CI → APK → verifikasi device.
