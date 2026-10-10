import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ssr_space/services/backup_json.dart';
import 'package:ssr_space/services/backup_service.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/export_files.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';

/// Cadangan JSON penuh + pulihkan (Batch 9 Sprint).
/// CSV lama tetap; JSON satu file utuh yang bisa dipulihkan:
/// dompet dicocokkan per nama (hilang = dibuat), transaksi dikode-ulang
/// server tanpa hash auto, cap 2000 baris. Butuh internet (tulis Supabase).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool backingUp = false;
  String? backupMsg;
  bool picking = false;
  ParsedBackup? preview;
  RestorePlan? plan;
  bool restoring = false;
  RestoreResult? result;
  String? err;

  Future<void> _backup() async {
    if (backingUp) return;
    setState(() {
      backingUp = true;
      backupMsg = null;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) throw StateError('org kosong');
      final orgName = await activeOrgName();
      final b = await fetchBackup(orgId, orgName);
      final content = jsonEncode(buildBackup(
        orgId: b.orgId,
        orgName: b.orgName,
        wallets: b.wallets,
        txs: b.txs,
        budgets: b.budgets,
      ));
      final now = DateTime.now();
      final name =
          'ssr-space-backup-${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}.json';
      try {
        final path = await saveBackupFile(name, content);
        await Share.shareXFiles(
          [XFile(path)],
          text: tr('bx_share'),
        );
      } on ExportNoPermission {
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/$name');
        await f.writeAsString(content);
        if (!mounted) return;
        await Share.shareXFiles([XFile(f.path)], text: tr('bx_share'));
      }
      if (!mounted) return;
      setState(() {
        backupMsg = tr('bx_backup_ok')
            .replaceFirst('{n}', '${b.txs.length}');
      });
    } catch (e, st) {
      ErrorReporter.capture(e, st, context: 'backup-json');
      if (!mounted) return;
      setState(() => err = tr('bx_backup_fail'));
    } finally {
      if (mounted) setState(() => backingUp = false);
    }
  }

  Future<void> _pick() async {
    if (picking) return;
    setState(() {
      picking = true;
      preview = null;
      plan = null;
      result = null;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) throw StateError('org kosong');
      final text = await pickBackupText();
      if (text == null) return; // user batal: diam
      ParsedBackup parsed;
      try {
        parsed = parseBackup(jsonDecode(text));
      } catch (_) {
        if (!mounted) return;
        setState(() => err = tr('bx_pick_fail'));
        return;
      }
      final p = await previewRestore(orgId, parsed);
      if (!mounted) return;
      setState(() {
        preview = parsed;
        plan = p;
      });
    } catch (e, st) {
      ErrorReporter.capture(e, st, context: 'restore-pick');
      if (!mounted) return;
      setState(() => err = tr('bx_pick_fail'));
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> _restore() async {
    final b = preview;
    if (b == null || restoring) return;
    setState(() {
      restoring = true;
      err = null;
      result = null;
    });
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) throw StateError('org kosong');
      final r = await restoreBackup(orgId, b);
      if (!mounted) return;
      setState(() => result = r);
    } catch (e, st) {
      ErrorReporter.capture(e, st, context: 'restore-run');
      if (!mounted) return;
      setState(() => err = tr('bx_restore_fail'));
    } finally {
      if (mounted) setState(() => restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('bx_title'))),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          SectionCard(
            margin: const EdgeInsets.only(bottom: SsrSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('bx_backup_t'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: SsrSpace.xs),
                Text(
                  tr('bx_backup_s'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: SsrSpace.md),
                if (backupMsg != null) ...[
                  Text(
                    backupMsg!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: SsrSpace.sm),
                ],
                PrimaryButton(
                  label: tr('bx_backup_btn'),
                  loading: backingUp,
                  onPressed: backingUp ? null : _backup,
                ),
              ],
            ),
          ),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('bx_restore_t'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: SsrSpace.xs),
                Text(
                  tr('bx_restore_s'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: SsrSpace.md),
                PrimaryButton(
                  label: tr('bx_restore_btn'),
                  loading: picking,
                  onPressed: picking ? null : _pick,
                ),
                if (preview != null && plan != null) ...[
                  const SizedBox(height: SsrSpace.md),
                  Text(
                    tr('bx_preview')
                        .replaceFirst('{t}', '${plan!.ready.length}')
                        .replaceFirst(
                            '{w}', '${plan!.missingWallets.length}')
                        .replaceFirst('{s}', '${plan!.skipped}'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (plan!.capped) ...[
                    const SizedBox(height: SsrSpace.xs),
                    Text(
                      tr('bx_capped'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: SsrSpace.sm),
                  PrimaryButton(
                    label: tr('bx_confirm'),
                    loading: restoring,
                    onPressed: restoring ? null : _restore,
                  ),
                ],
                if (result != null) ...[
                  const SizedBox(height: SsrSpace.md),
                  Text(
                    tr('bx_result')
                        .replaceFirst('{o}', '${result!.ok}')
                        .replaceFirst('{s}', '${result!.skipped}')
                        .replaceFirst('{f}', '${result!.failed}')
                        .replaceFirst('{w}', '${result!.walletsCreated}'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (err != null) ...[
                  const SizedBox(height: SsrSpace.md),
                  ErrorView(message: err!, onRetry: _pick),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
