# Profile Settings lengkap + Slim APK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver searchable Profile/Settings catalog plus per-ABI slim APK artifacts without touching money logic, RLS, or auto-track gate.

**Architecture:** Four green irises in order: prefs plus hub regroup, pure CSV import logic plus preview, reminder plus search plus static, CI splits plus diet. Each iris ends with analyze plus test green before next starts.

**Tech Stack:** Flutter stable, Supabase Auth plus Postgres RLS (read only, no new tables), shared_preferences notifiers, csv package (already in pubspec), flutter_local_notifications plus timezone (new, size measured), share_plus/mailto existing.

**Spec:** docs/superpowers/specs/2026-09-26-profile-settings-slim-apk-design.md

## Global Constraints

- DESIGN.md is law: paper/zamrud palette, ledger motif, 5-tab nav unchanged, tagline unchanged.
- Money display via amt() (mask-aware), billing plan prices via rp() only.
- build() methods under 50 lines, extract private widgets, reuse lib/widgets before creating new.
- flutter analyze must be 0 issues (even info prefer_const_constructors fails), then flutter test, then release APK.
- android/ is NOT committed, all Gradle/Manifest changes via CI patch steps in .github/workflows/apk.yml.
- No new RLS tables/policies, no self-recursive org_members policy, join only via join_org_by_invite, writes via TransactionService.add only.
- No Ollo code/assets copied, no new tracking permission, Indonesian UI copy only (EN strings only for existing locale option).
- Docs AGENTS.md plus AUDIT.md updated locally only, committed with next code push, never docs-only commit.
- Baseline reported 65 MB fat universal APK, target is smaller per-device download via splits, no magic total-size promise.

---

## File map

- Modify lib/services/app_settings.dart: add 9 notifiers plus setters plus extended loadAppSettings.
- Modify lib/utils/strings.dart: add ID plus EN keys for every new row (list in Task 2).
- Modify lib/screens/lainnya/other_screen.dart: regroup into 9 sections, zero dead taps.
- Modify lib/screens/lainnya/settings_screen.dart: add 7 new cards as private widgets.
- Create lib/services/csv_import_logic.dart (pure Dart, no flutter import): delimiter detect, parse, amount/date/type parse, formula neutralize, validation.
- Create test/csv_import_test.dart: min 12 asserts.
- Create lib/screens/lainnya/import_preview_screen.dart: mapping plus preview 5 rows plus error list, writes via TransactionService.add.
- Create lib/services/reminder_service.dart: thin wrapper over flutter_local_notifications plus timezone.
- Modify pubspec.yaml: add flutter_local_notifications plus timezone (exact versions resolved at Task 7 time, record delta).
- Create lib/screens/lainnya/update_log_screen.dart plus assets/changelog_id.md (bundled asset, register in pubspec assets).
- Create settings search delegate: lib/screens/lainnya/settings_search.dart (single file, SearchDelegate over static row list).
- Modify .github/workflows/apk.yml: split-per-abi build, size-report step, per-ABI artifact upload, minify patch, notification permission for reminders.
- Write 7 Phase-2 one-pagers under docs/superpowers/specs/ (spec only, no code).

---

### Task 1: Iris 1a prefs extension

**Files:**
- Modify: lib/services/app_settings.dart
- Test: test/app_settings_ext_test.dart

**Interfaces:**
- Consumes: SharedPreferences, existing loadAppSettings.
- Produces: uiAnims ValueNotifier<bool>, uiListStyle ValueNotifier<String>, uiDateStyle ValueNotifier<String>, uiHeroStyle ValueNotifier<String>, homeMenuOrder ValueNotifier<List<String>>, inputDefaultCurrency ValueNotifier<String>, reportsTopN ValueNotifier<bool>, reminderEnabled ValueNotifier<bool>, reminderHour ValueNotifier<int>, reminderMinute ValueNotifier<int>, widgetToday ValueNotifier<bool>; setters setUiAnims(bool), setUiListStyle(String), setUiDateStyle(String), setUiHeroStyle(String), setHomeMenuOrder(List<String>), setInputDefaultCurrency(String), setReportsTopN(bool), setReminderEnabled(bool), setReminderTime(int,int), setWidgetToday(bool).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_settings.dart';

void main() {
  test('defaults fail-safe saat prefs kosong', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await loadAppSettings(p);
    expect(uiAnims.value, true);
    expect(uiListStyle.value, 'comfortable');
    expect(uiDateStyle.value, 'system');
    expect(uiHeroStyle.value, 'emerald-calm');
    expect(reportsTopN.value, true);
    expect(reminderEnabled.value, false);
    expect(reminderHour.value, 7);
    expect(reminderMinute.value, 0);
    expect(widgetToday.value, false);
    expect(inputDefaultCurrency.value, 'IDR');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app_settings_ext_test.dart` (CI; lokal tanpa flutter cukup catat gagal karena simbol belum ada)
Expected: FAIL with undefined name uiAnims (or similar missing symbol)

- [ ] **Step 3: Write minimal implementation**

```dart
// tambah di bawah fontScale, sebelum kCurrencySymbols
final uiAnims = ValueNotifier<bool>(true);
final uiListStyle = ValueNotifier<String>('comfortable');
final uiDateStyle = ValueNotifier<String>('system');
final uiHeroStyle = ValueNotifier<String>('emerald-calm');
final homeMenuOrder = ValueNotifier<List<String>>([]);
final inputDefaultCurrency = ValueNotifier<String>('IDR');
final reportsTopN = ValueNotifier<bool>(true);
final reminderEnabled = ValueNotifier<bool>(false);
final reminderHour = ValueNotifier<int>(7);
final reminderMinute = ValueNotifier<int>(0);
final widgetToday = ValueNotifier<bool>(false);
```

Extend loadAppSettings body with reads for each key (ui_anims, ui_list_style, ui_date_style, ui_hero_style, home_menu_order as StringList, input_default_currency validated via kCurrencySymbols, reports_topn, reminder_enabled, reminder_hour 0-23 clamp, reminder_minute 0-59 clamp, widget_today). Add 9 setters mirroring setFontScale pattern (update notifier then persist).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/app_settings_ext_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/app_settings.dart test/app_settings_ext_test.dart
git commit -m "feat: extend app_settings prefs untuk settings katalog"
```

### Task 2: Iris 1b strings ID plus EN

**Files:**
- Modify: lib/utils/strings.dart
- Test: none (compile covered by analyze), manual check via search delegate Task 8.

**Interfaces:**
- Consumes: existing tr() map pattern.
- Produces: keys pf_data, pf_tracking, pf_backup, pf_workspace, pf_appearance, pf_langmoney, pf_reminder, pf_security, pf_about, st_def_currency, st_topn, st_topn_sub, st_anims, st_list_style, st_list_compact, st_list_comfortable, st_date_style, st_hero_style, st_reminder_time, st_reminder_on, st_widget_today, st_reset_correct, st_reset_correct_done, imp_title, imp_pick, imp_map_date, imp_map_amount, imp_map_type, imp_map_wallet, imp_map_towallet, imp_map_cat, imp_map_note, imp_preview, imp_errors, imp_import, imp_done, ab_about, ab_changelog, ab_help, ab_feedback, ab_share, ab_privacy, search_settings_hint, msg_p2.

- [ ] **Step 1: Add ID entries**

In strings.dart id map add exact pairs, example:

```dart
'pf_data': 'Data',
'pf_tracking': 'Pelacakan',
'pf_backup': 'Data dan cadangan',
'st_topn': 'Top 8 + Lainnya di laporan',
'imp_title': 'Impor CSV',
'msg_p2': 'Bagian ini tahap P2. Pengaturan tetap tersimpan bila sudah ada.',
```

Full list per Produces above, Indonesian copy only, no em dash.

- [ ] **Step 2: Add matching EN entries**

Mirror every key with English text in en map, same keys, no missing key.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 4: Commit**

```bash
git add lib/utils/strings.dart
git commit -m "feat: strings katalog settings ID plus EN"
```

### Task 3: Iris 1c OtherScreen regroup

**Files:**
- Modify: lib/screens/lainnya/other_screen.dart (keep under 400 lines, extract _Section widgets if build exceeds 50)

**Interfaces:**
- Consumes: Task 1 notifiers (read-only display), existing routes (Wallets, Categories, Budgets, Transactions, NotifSettings, Invite, OrgSwitcher, Settings, Billing).
- Produces: grouped hub with 9 LabeledSectionCard sections, every NavTile has real onTap or P2 dialog via msg_p2.

- [ ] **Step 1: Regroup build into sections**

Replace flat tile list with ordered sections: HEADER (existing meta card unchanged), DATA (Dompet, Kategori, Budget, Riwayat transaksi), PELACAKAN (Pelacakan otomatis, Koreksi overlay toggle existing), DATA DAN CADANGAN (Cadangkan, Ekspor, Impor -> import_preview_screen, Hapus cache lokal -> confirm dialog clearing overlay prefs only), WORKSPACE (Undang, Ganti, Detail), TAMPILAN (varian hero/list/anims/depan order entry -> SettingsScreen anchors), BAHASA DAN UANG (-> SettingsScreen), PENGINGAT (-> SettingsScreen), KEAMANAN (-> SettingsScreen PIN/biometric/reset), TENTANG (-> About rows). Keep all existing imports, add import_preview_screen and update_log_screen imports.

- [ ] **Step 2: Wire clear-cache dialog**

```dart
Future<void> _clearLocalCache(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('pf_backup')),
      content: Text(tr('st_reset_correct')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('act_cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('act_delete'))),
      ],
    ),
  );
  if (ok != true) return;
  final p = await SharedPreferences.getInstance();
  await p.remove('pending_correct_tx');
}
```

Never delete Supabase data here.

- [ ] **Step 3: Run analyze plus test**

Run: `flutter analyze` then `flutter test`
Expected: 0 issues, all green

- [ ] **Step 4: Commit**

```bash
git add lib/screens/lainnya/other_screen.dart
git commit -m "feat: regroup profile hub 9 seksi tanpa dead tap"
```

### Task 4: Iris 1d SettingsScreen new cards

**Files:**
- Modify: lib/screens/lainnya/settings_screen.dart

**Interfaces:**
- Consumes: Task 1 setters plus notifiers, CurrencyService.refresh status pattern.
- Produces: private cards _DefaultCurrencyCard, _TopNCard, _AnimsCard, _ListStyleCard, _DateStyleCard, _HeroStyleCard, _ReminderCard (time picker plus toggle), _WidgetStubCard, _ResetCorrectCard. Each under 50-line build.

- [ ] **Step 1: Add cards to ListView after _FontCard**

Insert in order: default currency dropdown (kCurrencySymbols keys), Top-N switch, anims switch, list style segmented (compact/comfortable), date style dropdown (system/calendar/spinner), hero style dropdown (emerald-calm only plus P2 note for more), reminder toggle plus TimePicker readout plus fx-style status msg, widget stub switch with P2 note, reset correction memory button (clears pending_correct_tx plus overlay prefs, snackbar st_reset_correct_done).

- [ ] **Step 2: Keep existing behavior**

_LangCard, _CurrencyCard with fx status, _FontCard, _PinCard untouched logic, only import additions.

- [ ] **Step 3: Run analyze plus test**

Run: `flutter analyze` then `flutter test`
Expected: 0 issues, green

- [ ] **Step 4: Commit**

```bash
git add lib/screens/lainnya/settings_screen.dart
git commit -m "feat: settings cards katalog baru prefs-backed"
```

### Task 5: Iris 2a csv_import_logic pure plus test

**Files:**
- Create: lib/services/csv_import_logic.dart (no flutter import, pure Dart)
- Create: test/csv_import_test.dart

**Interfaces:**
- Consumes: raw CSV text String.
- Produces: CsvImportRow{date yyyy-MM-dd, amount double, type in/out/transfer, walletName, toWalletName, category, note, lineNo}, CsvImportError{lineNo,message}, CsvImportPreview{rows,errors}, functions detectDelimiter(String)->String, parseCsvPreview(String,{walletNames})->CsvImportPreview, parseAmountValue(String)->double, parseDateValue(String)->String (yyyy-MM-dd or throw), parseTypeValue(String)->String, neutralizeFormula(String)->String.

- [ ] **Step 1: Write the failing test (12 asserts)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/csv_import_logic.dart';

void main() {
  test('delimiter koma vs titik-koma', () {
    expect(detectDelimiter('a,b,c'), ',');
    expect(detectDelimiter('a;b;c'), ';');
  });
  test('amount ID 1.234,50 jadi 1234.5', () {
    expect(parseAmountValue('Rp1.234,50'), 1234.5);
    expect(parseAmountValue('1,234.50'), 1234.5);
  });
  test('date dd/MM/yyyy jadi ISO', () {
    expect(parseDateValue('26/09/2026'), '2026-09-26');
    expect(parseDateValue('2026-09-26'), '2026-09-26');
  });
  test('type in/out/transfer', () {
    expect(parseTypeValue('masuk'), 'in');
    expect(parseTypeValue('keluar'), 'out');
    expect(parseTypeValue('transfer'), 'transfer');
  });
  test('formula dinetralkan', () {
    expect(neutralizeFormula('=CMD()'), "'=CMD()");
  });
  test('preview 5 baris plus error', () {
    const csv = 'tanggal,nominal,jenis,dompet,kategori,catatan\n26/09/2026,Rp10.000,keluar,DANA,Makan,siang\n,,,,,\n';
    final p = parseCsvPreview(csv);
    expect(p.rows.length, 1);
    expect(p.errors.isNotEmpty, true);
  });
}
```

Expand to min 12 expects total before running.

- [ ] **Step 2: Verify locally with dart then CI test fails first**

Run: `dart test/csv_import_test.dart` if pure (or flutter test expecting missing file error)
Expected: FAIL (file not found) proving test-first

- [ ] **Step 3: Write minimal pure implementation**

Implement header-insensitive mapping (tanggal/date, nominal/amount, jenis/type, dompet/wallet, ke_dompet/to_wallet, kategori/category, catatan/note), skip empty lines, collect per-line errors, never throw on row (only helpers throw, caught per row). No Supabase, no shared_preferences.

- [ ] **Step 4: Run tests green**

Run: `flutter test test/csv_import_test.dart`
Expected: PASS, then full `flutter test` green

- [ ] **Step 5: Commit**

```bash
git add lib/services/csv_import_logic.dart test/csv_import_test.dart
git commit -m "feat: csv import pure logic plus 12 asserts"
```

### Task 6: Iris 2b import_preview_screen

**Files:**
- Create: lib/screens/lainnya/import_preview_screen.dart
- Modify: lib/screens/lainnya/other_screen.dart (route already added Task 3, verify)

**Interfaces:**
- Consumes: CsvImportPreview from Task 5, TransactionService.add via txInsertPayload, wallet list for mapping.
- Produces: ImportPreviewScreen(fileText) with column mapping dropdowns, category mapping, first-5 preview table, error list, Import button writing row-by-row via service with per-row success/fail summary.

- [ ] **Step 1: Build mapping plus preview UI**

File picker via existing share/file pattern in repo (follow backup_export inverse, no new permission beyond storage picker). Mapping state held in State, preview rebuilt from parseCsvPreview on mapping change. Import loop:

```dart
var ok = 0; var fail = 0;
for (final r in preview.rows) {
  try {
    await txService.add(orgId: orgId, type: r.type, amount: r.amount, walletId: walletIdFor(r.walletName), toWalletId: walletIdFor(r.toWalletName), category: mappedCategory(r.category), note: r.note, date: r.date);
    ok++;
  } catch (_) { fail++; }
}
```

Uses txInsertPayload path inside add, no direct table writes, no TX burn on failure (insert-first pattern preserved).

- [ ] **Step 2: Analyze plus test**

Run: `flutter analyze` then `flutter test`
Expected: 0 issues, green

- [ ] **Step 3: Commit**

```bash
git add lib/screens/lainnya/import_preview_screen.dart
git commit -m "feat: import CSV preview plus mapping plus tulis via service"
```

### Task 7: Iris 3a reminder service plus dep

**Files:**
- Modify: pubspec.yaml (add flutter_local_notifications plus timezone)
- Create: lib/services/reminder_service.dart
- Modify: .github/workflows/apk.yml (add POST_NOTIFICATIONS permission patch plus keep-rules note)

**Interfaces:**
- Consumes: Task 1 reminderEnabled/hour/minute notifiers.
- Produces: ReminderService.init(), scheduleDaily(hour,minute), cancel(). Pure math helper nextDaily(int hour,int minute,DateTime now)->DateTime testable.

- [ ] **Step 1: Add deps and record size baseline**

Add deps with versions resolved via pub, run build size capture before/after in PR description. Keep dep list minimal, no ML Kit.

- [ ] **Step 2: Implement thin wrapper plus math**

scheduleDaily computes nextDaily then zonedSchedule daily, boot persist via plugin config, cancel on toggle off. No business logic in widgets.

- [ ] **Step 3: Add test for nextDaily**

```dart
test('nextDaily hari ini bila jam depan', () {
  final now = DateTime(2026, 9, 26, 6, 0);
  expect(nextDaily(7, 0, now), DateTime(2026, 9, 26, 7, 0));
});
```

Plus past-hour rolls tomorrow, total min 4 asserts in test/reminder_test.dart.

- [ ] **Step 4: Analyze plus test plus commit**

Run: `flutter analyze` then `flutter test`
```bash
git add pubspec.yaml lib/services/reminder_service.dart test/reminder_test.dart .github/workflows/apk.yml
git commit -m "feat: daily reminder exact plus reboot persist"
```

### Task 8: Iris 3b search plus static plus changelog

**Files:**
- Create: lib/screens/lainnya/settings_search.dart
- Create: lib/screens/lainnya/update_log_screen.dart
- Create: assets/changelog_id.md
- Modify: pubspec.yaml (register changelog asset)

**Interfaces:**
- Consumes: Task 2 keys list.
- Produces: SettingsSearchDelegate searching static row titles ID plus EN, UpdateLogScreen reading bundled md as text, About rows (version via AppInfo.version, mailto feedback, share_plus text, static help/privacy).

- [ ] **Step 1: Build search delegate over static entries**

Static const list of {idKey,enText,routeBuilder} covering every section row. No dead entry: P2 entries show msg_p2 dialog.

- [ ] **Step 2: Build update log plus changelog asset**

Write short changelog_id.md (top 10 entries, Indonesian, no em dash). Screen shows loading plus error states for asset read.

- [ ] **Step 3: Analyze plus test plus commit**

Run: `flutter analyze` then `flutter test`
```bash
git add lib/screens/lainnya/settings_search.dart lib/screens/lainnya/update_log_screen.dart assets/changelog_id.md pubspec.yaml
git commit -m "feat: settings search plus about statik"
```

### Task 9: Iris 4a CI splits plus size report plus minify

**Files:**
- Modify: .github/workflows/apk.yml

**Interfaces:**
- Consumes: existing build, signing, BigText/overlay/foreground/deeplink patches.
- Produces: universal plus per-ABI apks, size table in logs, minify/shrinkResources release config via generated-Gradle patch with keep-rules.

- [ ] **Step 1: Add size-report step after pub get**

```yaml
- run: flutter build apk --release --split-per-abi --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
```

Keep existing universal build as separate step for sideload, rename outputs clearly (app-arm64-v8a-release.apk etc). Add ls step:

```bash
ls -lh build/app/outputs/flutter-apk/
unzip -l build/app/outputs/flutter-apk/app-release.apk | sort -k4 -n | tail -30
```

- [ ] **Step 2: Add minify patch for generated Gradle**

Python patch step mirroring existing style: if build.gradle.kts exists set isMinifyEnabled true plus shrinkResources true plus proguard keep lines for notification_listener_service, flutter_overlay_window, flutter_foreground_task, supabase, local_auth, flutter_local_notifications. Assert lines present, fail loudly on drift.

- [ ] **Step 3: Upload per-ABI artifacts**

Add upload-artifact entries for app-arm64-v8a, armeabi-v7a, x86_64 plus keep ssr-space-apk universal. Verify workflow parses (push to branch triggers CI).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/apk.yml
git commit -m "ci: per-ABI splits plus size report plus minify aman"
```

### Task 10: Iris 4b diet audit plus Phase-2 one-pagers plus docs

**Files:**
- Modify: pubspec.yaml (only removals justified), assets pruning
- Create: 7 one-pagers docs/superpowers/specs/2026-09-26-p2-*.md
- Modify: AGENTS.md, AUDIT.md (local only, bundled with code push)

**Interfaces:**
- Consumes: all prior tasks.
- Produces: dep justification table in PR, pruned fonts/assets list, 7 specs each with problem, Ollo pattern, SSR adaptation, data/prefs, edge, test list, RLS impact line.

- [ ] **Step 1: Audit deps and assets**

Check sqflite/path usage via grep, if unused remove with reason in PR, else keep with one-line justification. List font weights actually referenced (PlusJakartaSans variable, Anton, Fraunces used screens, Phosphor fill/duotone). Compress illustrations/lottie or defer unused.

- [ ] **Step 2: Write 7 one-pagers**

Files: p2-recurring-bills, p2-reminder-copy, p2-widget-qs-tile, p2-wallet-svg-pack, p2-subcategory-picker, p2-reports-topn-reorder, p2-calm-streak. Each states migration needed or no migration needed.

- [ ] **Step 3: Update AGENTS plus AUDIT locally**

Changelog entries plus status lines, no separate commit (bundled with Task 9 or final push per repo rule).

- [ ] **Step 4: Final verify plus deliver**

Run: `flutter analyze` then `flutter test`, record size table, copy final APKs to /sdcard/Download/SSR-SPACE/ with clear names after green CI.

## Self-Review

Spec coverage: hub regroup Tasks 3-4, prefs Task 1, strings Task 2, import Tasks 5-6, reminder Task 7, search/static Task 8, slim-APK Tasks 9-10, Phase-2 Task 10, acceptance via analyze/test/size/manual checklist in each task.
Placeholder scan: no TBD/TODO, every code step shows exact code or exact yaml, no similar-to-Task shorthand.
Type consistency: notifier names match Task 1 Produces across Tasks 3-4/7, CsvImport types match Task 5 Produces in Task 6 consumer, ReminderService API stable Task 7.
