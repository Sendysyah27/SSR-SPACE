import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ssr_space/services/backup_crypto.dart';
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
  bool backingUpEnc = false;
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

  /// Minta password cadangan ke user. [confirm]=true = minta 2x.
  /// Return null bila batal.
  Future<String?> _askBackupPassword({required bool confirm}) async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    final pass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('bx_enc_pass_t')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: c1,
              obscureText: true,
              decoration:
                  InputDecoration(hintText: tr('bx_enc_pass_hint')),
            ),
            if (confirm) ...[
              const SizedBox(height: 8),
              TextField(
                controller: c2,
                obscureText: true,
                decoration:
                    InputDecoration(hintText: tr('bx_enc_pass2_hint')),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('close')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c1.text),
            child: Text(tr('bx_paste_ok')),
          ),
        ],
      ),
    );
    final p2 = c2.text;
    c1.dispose();
    c2.dispose();
    if (pass == null) return null; // batal: diam
    if (pass.length < 8) {
      if (!mounted) return null;
      setState(() => err = tr('bx_enc_pass_short'));
      return null;
    }
    if (confirm && pass != p2) {
      if (!mounted) return null;
      setState(() => err = tr('bx_enc_pass_mismatch'));
      return null;
    }
    return pass;
  }

  /// Cadangan terenkripsi: JSON -> zip AES-256 berpassword -> base64 teks
  /// -> share sebagai file .enc.txt -> file temp DIHAPUS setelah share.
  /// Opsi cadangan biasa tetap ada (kompatibilitas).
  Future<void> _backupEncrypted() async {
    if (backingUp || backingUpEnc) return;
    final pass = await _askBackupPassword(confirm: true);
    if (pass == null) return;
    setState(() {
      backingUpEnc = true;
      backupMsg = null;
      err = null;
    });
    File? tmp;
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
      final payload = encryptBackup(content, pass);
      final now = DateTime.now();
      final name =
          'ssr-space-backup-${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}.enc.txt';
      final dir = await getTemporaryDirectory();
      tmp = File('${dir.path}/$name');
      await tmp.writeAsString(payload);
      await Share.shareXFiles([XFile(tmp.path)], text: tr('bx_share'));
      if (!mounted) return;
      setState(() {
        backupMsg =
            tr('bx_enc_ok').replaceFirst('{n}', '${b.txs.length}');
      });
    } catch (e, st) {
      ErrorReporter.capture(e, st, context: 'backup-enc');
      if (!mounted) return;
      setState(() => err = tr('bx_backup_fail'));
    } finally {
      // File temp jangan tertinggal di storage.
      try {
        await tmp?.delete();
      } catch (_) {}
      if (mounted) setState(() => backingUpEnc = false);
    }
  }

  /// Dekripsi payload tempel (terdeteksi via marker). Return null bila
  /// batal / password salah (err sudah diset).
  Future<String?> _decryptPasted(String raw) async {
    final pass = await _askBackupPassword(confirm: false);
    if (pass == null || pass.isEmpty) return null;
    try {
      return decryptBackup(raw, pass);
    } on BackupDecryptException {
      if (!mounted) return null;
      setState(() => err = tr('bx_enc_wrong'));
      return null;
    }
  }

  Future<void> _pick() async {
    if (picking) return;
    final c = TextEditingController();
    final pasted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('bx_paste_t')),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: c,
            maxLines: 8,
            decoration: const InputDecoration(hintText: '{"app":"ssr-space",…}'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('close')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: Text(tr('bx_paste_ok')),
          ),
        ],
      ),
    );
    c.dispose();
    if (pasted == null || pasted.trim().isEmpty) return; // batal: diam
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
      ParsedBackup parsed;
      try {
        final raw = pasted.trim();
        final jsonText = raw.startsWith(encBackupMarker)
            ? await _decryptPasted(raw)
            : raw;
        if (jsonText == null) return; // batal / password salah
        parsed = parseBackup(jsonDecode(jsonText));
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
                const SizedBox(height: SsrSpace.sm),
                Text(
                  tr('bx_enc_s'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: SsrSpace.xs),
                PrimaryButton(
                  label: tr('bx_enc_btn'),
                  loading: backingUpEnc,
                  onPressed: (backingUp || backingUpEnc)
                      ? null
                      : _backupEncrypted,
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
                  // Tertahan kuota paket = bukan gagal generik: tampilkan
                  // pesan kuota jujur (tanpa kunci strings baru).
                  if (result!.quotaBlocked > 0) ...[
                    const SizedBox(height: SsrSpace.xs),
                    Text(
                      '${result!.quotaBlocked} ${tr('q_wallet_exceeded')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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
