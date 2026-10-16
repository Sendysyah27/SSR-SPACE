# Kickoff: Adaptasi kapabilitas Ollo ke SSR SPACE

Repo: ~/SSRSPACE (Flutter + Kotlin android-native + Supabase).
Tujuan: adaptasi KONSEP 5 kapabilitas dari hasil RE app Ollo (com.ollo.ollo):
1. Widget & quick-entry suite (widget saldo/budget/hari-ini + QS tile + deep link)
2. Gamifikasi: streak & badge (extend calm_streak.dart, game_badges.dart)
3. Limit free + VIP/entitlement server-side (extend plan_limits.dart + migrasi kuota 17)
4. Announcements + Roadmap + Update-log (extend update_log_screen.dart)
5. i18n multi-bahasa + multi-currency/exchange-rate
Backend: SEMUA via Supabase (RLS + RPC/edge function). JANGAN pakai api.olloweb.app.

Baca dulu (referensi perilaku, jangan dikutip mentah):
- /sdcard/Download/revapp-ollo/LAPORAN-ollo.md
- /sdcard/Download/revapp-ollo/fitur.json
- ollo-reveng-v1.7.7.zip → routes/endpoint/changelog
- /sdcard/Download/revapp-ollo/desain-ollo/ → aset visual Ollo (card background,
  onboarding, mascot, splash, ikon) — referensi rasa visual saja
- docs/reference/ollo-screenshots/ → screenshot app Ollo (bila sudah diisi owner):
  pelajari POLA FLOW & hierarki aksi per layar, bukan visual/mereknya

Aturan main (WAJIB):
- Ikuti AGENTS.md repo (workflow, worktree, migrasi §3.4, rls-test) + DESIGN.md.
- Alur: brainstorming → spec per fase ke docs/superpowers/specs/ → writing-plans →
  eksekusi per fase. Dilarang langsung koding.
- Audit dulu fitur existing yang beririsan (calm_streak, game_badges, plan_limits,
  today_widget, widget_snapshot, update_log_screen, billing_service, invite_token,
  reminder_*, currency) → extend, jangan duplikasi.
- Flutter tidak terpasang di Termux → verifikasi via CI (build-apk + rls-test).
- Adaptasi konsep saja: tanpa merek/aset/teks Ollo; nama tetap SSR SPACE.
- i18n = refactor besar → fase tersendiri, incremental, jangan campur fitur lain.
- Urutan fase usulan: (1) entitlement+limit, (2) widget+quick-entry, (3) gamifikasi,
  (4) announcements/roadmap/update-log, (5) i18n + multi-currency.

Output sesi pertama: spec fase 1 + implementation plan-nya. Tunggu approval owner
sebelum mengeksekusi kode.
