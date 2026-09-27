import 'package:flutter/material.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/csv_import_logic.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/labeled_section_card.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';

/// Contoh header untuk kolom tempel (data format, bukan copy UI).
const _kCsvHint = 'tanggal,nominal,jenis,dompet,kategori,catatan';

/// Field pratinjau + kunci labelnya, urutan tampil di kartu pemetaan.
const _kMapFields = <(String, String)>[
  ('date', 'imp_map_date'),
  ('amount', 'imp_map_amount'),
  ('type', 'imp_map_type'),
  ('wallet', 'imp_map_wallet'),
  ('towallet', 'imp_map_towallet'),
  ('cat', 'imp_map_cat'),
  ('note', 'imp_map_note'),
];

/// Baca ulang header baris pertama via parseHeaderNames (logika murni,
/// alias sama persis dengan parser): field -> nama header asli.
Map<String, String?> importHeaderMapping(String text) {
  final nl = text.indexOf('\n');
  final head = (nl < 0 ? text : text.substring(0, nl)).trim();
  return parseHeaderNames(head, detectDelimiter(text));
}

/// Cocokkan nama dompet CSV ke id dompet org (tak sensitif huruf).
String? matchWalletId(List<Wallet> wallets, String name) {
  final t = name.trim().toLowerCase();
  if (t.isEmpty) return null;
  for (final w in wallets) {
    if (w.name.trim().toLowerCase() == t) return w.id;
  }
  return null;
}

/// Cocokkan kategori CSV ke daftar global (kembalikan ejaan kanonis).
String? matchCategory(List<String> cats, String name) {
  final t = name.trim().toLowerCase();
  if (t.isEmpty) return null;
  for (final c in cats) {
    if (c.trim().toLowerCase() == t) return c;
  }
  return null;
}

String _walletNameOf(List<Wallet> wallets, String? id, String fallback) {
  if (id == null) return fallback;
  for (final w in wallets) {
    if (w.id == id) return w.name;
  }
  return fallback;
}

/// Layar Impor CSV (paste teks, tanpa file picker): tempel, pratinjau
/// pemetaan + 5 baris pertama, pilih dompet fallback, tulis via service.
class ImportPreviewScreen extends StatefulWidget {
  const ImportPreviewScreen({super.key});

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewState();
}

class _ImportPreviewState extends State<ImportPreviewScreen> {
  final _text = TextEditingController();
  String _orgId = '';
  List<Wallet> _wallets = const [];
  String? _fallbackWalletId;
  String? _fallbackCategory;
  CsvImportPreview? _preview;
  Map<String, String?>? _mapping;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadWallets() async {
    final orgId = await activeOrgId();
    if (!mounted) return;
    if (orgId.isEmpty) {
      setState(() => _orgId = '');
      return;
    }
    try {
      final ws = await WalletService().list(orgId);
      if (!mounted) return;
      setState(() {
        _orgId = orgId;
        _wallets = ws;
        _fallbackWalletId = ws.isEmpty ? null : ws.first.id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _orgId = orgId);
    }
  }

  void _onPreview() {
    if (_importing) return;
    setState(() {
      _preview = parseCsvPreview(_text.text);
      _mapping = importHeaderMapping(_text.text);
    });
  }

  String? _walletFor(CsvImportRow r) =>
      matchWalletId(_wallets, r.walletName) ?? _fallbackWalletId;

  String? _toWalletFor(CsvImportRow r, String? src) => resolveToWalletId(
    type: r.type,
    matchedToId: matchWalletId(_wallets, r.toWalletName),
    srcId: src,
    fallbackId: _fallbackWalletId,
  );

  String? _catFor(CsvImportRow r) =>
      matchCategory(appCategories.value, r.category) ?? _fallbackCategory;

  /// Tulis baris per baris via service, fail-open: satu baris gagal
  /// (dompet tak ketemu, RLS, duplikat) tak menghentikan baris lain.
  Future<void> _onImport() async {
    final pv = _preview;
    if (pv == null || pv.rows.isEmpty || _importing || _orgId.isEmpty) return;
    setState(() => _importing = true);
    var ok = 0;
    var fail = 0;
    for (final r in pv.rows) {
      try {
        final wid = _walletFor(r);
        if (wid == null) {
          fail++;
          continue;
        }
        final toWid = _toWalletFor(r, wid);
        if (r.type == 'transfer' && toWid == null) {
          fail++;
          continue;
        }
        await TransactionService().add(
          orgId: _orgId,
          type: r.type,
          amount: r.amount,
          walletId: wid,
          toWalletId: toWid,
          category: _catFor(r),
          note: r.note.isEmpty ? null : r.note,
          date: r.date,
        );
        ok++;
      } catch (_) {
        fail++;
      }
    }
    if (mounted) setState(() => _importing = false);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('imp_import')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('imp_done').replaceFirst('{n}', '$ok')),
            if (fail > 0) ...[
              const SizedBox(height: SsrSpace.sm),
              Text(tr('imp_errors').replaceFirst('{n}', '$fail')),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('back')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pv = _preview;
    return Scaffold(
      appBar: AppBar(title: Text(tr('imp_title'))),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          _PasteCard(
            controller: _text,
            importing: _importing,
            onPreview: _onPreview,
          ),
          if (_importing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: SsrSpace.sm),
              child: LinearProgressIndicator(),
            ),
          if (pv == null)
            _EmptyHint(onPreview: _onPreview)
          else if (pv.rows.isEmpty)
            _ErrorsCard(errors: pv.errors)
          else ...[
            _MappingCard(mapping: _mapping ?? const {}),
            _RowsCard(
              rows: pv.rows,
              wallets: _wallets,
              fallbackWalletId: _fallbackWalletId,
              fallbackCategory: _fallbackCategory,
            ),
            _FallbackCard(
              wallets: _wallets,
              fallbackWalletId: _fallbackWalletId,
              onWalletChanged: (v) => setState(() => _fallbackWalletId = v),
              fallbackCategory: _fallbackCategory,
              onCategoryChanged: (v) => setState(() => _fallbackCategory = v),
              importing: _importing,
              canImport: _orgId.isNotEmpty && _wallets.isNotEmpty,
              onImport: _onImport,
            ),
            if (pv.errors.isNotEmpty) _ErrorsCard(errors: pv.errors),
          ],
        ],
      ),
    );
  }
}

/// Kartu tempel CSV + tombol Pratinjau.
class _PasteCard extends StatelessWidget {
  final TextEditingController controller;
  final bool importing;
  final VoidCallback onPreview;

  const _PasteCard({
    required this.controller,
    required this.importing,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      color: SsrColors.noirSurface,
      borderColor: SsrColors.noirLine,
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('imp_title'),
      children: [
        TextField(
          controller: controller,
          minLines: 5,
          maxLines: 8,
          enabled: !importing,
          decoration: const InputDecoration(hintText: _kCsvHint),
        ),
        const SizedBox(height: SsrSpace.md),
        PrimaryButton(
          label: tr('imp_preview'),
          onPressed: importing ? null : onPreview,
        ),
      ],
    );
  }
}

/// Status kosong: belum ada teks yang dipratinjau.
class _EmptyHint extends StatelessWidget {
  final VoidCallback onPreview;

  const _EmptyHint({required this.onPreview});

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: AppIcons.arrowDown,
      title: tr('imp_title'),
      subtitle: _kCsvHint,
      actionLabel: tr('imp_preview'),
      onAction: onPreview,
    );
  }
}

/// Hasil baca header: kolom CSV apa mengisi field apa.
class _MappingCard extends StatelessWidget {
  final Map<String, String?> mapping;

  const _MappingCard({required this.mapping});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      color: SsrColors.noirSurface,
      borderColor: SsrColors.noirLine,
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('imp_preview'),
      children: [for (final f in _kMapFields) _mapRow(f.$2, mapping[f.$1])],
    );
  }

  Widget _mapRow(String labelKey, String? header) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.xs),
      child: Row(
        children: [
          Expanded(child: Text(tr(labelKey))),
          StatusChip(
            label: header ?? tr('nt_wallet_unset'),
            tone: header == null ? StatusTone.neutral : StatusTone.accent,
          ),
        ],
      ),
    );
  }
}

/// Lima baris pertama yang valid: tanggal, jenis, nominal, dompet.
class _RowsCard extends StatelessWidget {
  final List<CsvImportRow> rows;
  final List<Wallet> wallets;
  final String? fallbackWalletId;
  final String? fallbackCategory;

  const _RowsCard({
    required this.rows,
    required this.wallets,
    required this.fallbackWalletId,
    required this.fallbackCategory,
  });

  @override
  Widget build(BuildContext context) {
    final shown = rows.take(5).toList();
    final rest = rows.length - shown.length;
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      color: SsrColors.noirSurface,
      borderColor: SsrColors.noirLine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in shown) _rowTile(context, r),
          if (rest > 0) Text('+$rest'),
        ],
      ),
    );
  }

  Widget _rowTile(BuildContext context, CsvImportRow r) {
    final theme = Theme.of(context);
    final wid = matchWalletId(wallets, r.walletName) ?? fallbackWalletId;
    final cat =
        matchCategory(appCategories.value, r.category) ?? fallbackCategory;
    final srcName = _walletNameOf(wallets, wid, tr('nt_wallet_unset'));
    final catName = cat ?? tr('cat_other');
    final String detail;
    if (r.type == 'transfer') {
      final toWid = resolveToWalletId(
        type: r.type,
        matchedToId: matchWalletId(wallets, r.toWalletName),
        srcId: wid,
        fallbackId: fallbackWalletId,
      );
      final dstName = _walletNameOf(wallets, toWid, tr('nt_wallet_unset'));
      detail = '$srcName → $dstName - $catName';
    } else {
      detail = '$srcName - $catName';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.date, style: theme.textTheme.bodyMedium),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          StatusChip(label: _typeLabel(r.type), tone: _typeTone(r.type)),
          const SizedBox(width: SsrSpace.sm),
          Text(
            amt(r.amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'in':
        return tr('tx_in');
      case 'out':
        return tr('tx_out');
      default:
        return tr('tx_transfer');
    }
  }

  StatusTone _typeTone(String type) {
    switch (type) {
      case 'in':
        return StatusTone.accent;
      case 'out':
        return StatusTone.danger;
      default:
        return StatusTone.neutral;
    }
  }
}

/// Dompet + kategori fallback dan tombol Impor.
class _FallbackCard extends StatelessWidget {
  final List<Wallet> wallets;
  final String? fallbackWalletId;
  final ValueChanged<String?> onWalletChanged;
  final String? fallbackCategory;
  final ValueChanged<String?> onCategoryChanged;
  final bool importing;
  final bool canImport;
  final VoidCallback onImport;

  const _FallbackCard({
    required this.wallets,
    required this.fallbackWalletId,
    required this.onWalletChanged,
    required this.fallbackCategory,
    required this.onCategoryChanged,
    required this.importing,
    required this.canImport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      color: SsrColors.noirSurface,
      borderColor: SsrColors.noirLine,
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('imp_import'),
      children: [
        if (wallets.isEmpty)
          Text(tr('nt_nowallet'), style: Theme.of(context).textTheme.bodySmall)
        else
          DropdownButtonFormField<String>(
            initialValue: fallbackWalletId,
            decoration: InputDecoration(labelText: tr('o_wallets')),
            items: [
              for (final w in wallets)
                DropdownMenuItem(value: w.id, child: Text(w.name)),
            ],
            onChanged: importing ? null : onWalletChanged,
          ),
        const SizedBox(height: SsrSpace.md),
        DropdownButtonFormField<String>(
          initialValue: fallbackCategory,
          decoration: InputDecoration(labelText: tr('o_cats')),
          items: [
            DropdownMenuItem(value: null, child: Text(tr('cat_other'))),
            for (final c in appCategories.value)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: importing ? null : onCategoryChanged,
        ),
        const SizedBox(height: SsrSpace.md),
        PrimaryButton(
          label: tr('imp_import'),
          onPressed: canImport && !importing ? onImport : null,
          loading: importing,
        ),
      ],
    );
  }
}

/// Status galat: semua baris tak valid, atau sisa baris bermasalah.
class _ErrorsCard extends StatelessWidget {
  final List<CsvImportError> errors;

  const _ErrorsCard({required this.errors});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      color: SsrColors.noirSurface,
      borderColor: SsrColors.noirLine,
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('imp_errors').replaceFirst('{n}', '${errors.length}'),
      children: [
        for (final e in errors)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: SsrSpace.xs),
            child: Text(
              '${e.lineNo}: ${e.message}',
              style: const TextStyle(color: SsrColors.rose),
            ),
          ),
      ],
    );
  }
}
