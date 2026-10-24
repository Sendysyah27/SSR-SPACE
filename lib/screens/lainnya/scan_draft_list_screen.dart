import 'package:flutter/material.dart';

import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/services/scan_draft_store.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/entry/receipt_draft_review.dart';

/// Daftar draft scan tersimpan (batch 286 tahap C).
///
/// Ketuk draft -> review terstruktur yang sama seperti hasil scan
/// baru ([reviewScanDraft]); hasil review yang dipakai dikembalikan
/// ke pemanggil sebagai [ReceiptData] lewat pop. Draft tidak
/// kedaluwarsa otomatis — hanya hilang bila dipakai sampai jadi
/// transaksi, dibuang dari review, atau dihapus dari daftar ini.
class ScanDraftListScreen extends StatefulWidget {
  const ScanDraftListScreen({super.key});

  @override
  State<ScanDraftListScreen> createState() => _ScanDraftListScreenState();
}

class _ScanDraftListScreenState extends State<ScanDraftListScreen> {
  final _store = ScanDraftStore();
  List<ScanDraftEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _store.list();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _open(ScanDraftEntry entry) async {
    final outcome = await reviewScanDraft(
      context,
      entry.draft.toReceiptData(),
      existingDraftId: entry.id,
    );
    if (!mounted) return;
    if (outcome.data != null) {
      Navigator.of(context).pop<ReceiptData>(outcome.data);
      return;
    }
    if (outcome.savedDraft) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('scan_draft_saved'))),
      );
    }
    await _load();
  }

  Future<void> _delete(ScanDraftEntry entry) async {
    await _store.remove(entry.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      backgroundColor: DribTokens.bgOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr('scan_drafts'),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(SsrSpace.lg),
                    child: Text(
                      tr('scan_draft_empty'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(SsrSpace.md),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: SsrSpace.sm),
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    final d = e.draft;
                    final title = d.merchant?.trim();
                    return Card(
                      color: DribTokens.cardOf(context),
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(DribTokens.cardRadius),
                        side: const BorderSide(color: DribTokens.border),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: DribTokens.pinkBg,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            color: DribTokens.pink,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          (title == null || title.isEmpty) ? '-' : title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (d.date != null) d.date!,
                            if (d.time != null) d.time!,
                            if (d.total != null) _rp(d.total!),
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: DribTokens.errorText,
                          ),
                          tooltip: tr('scan_draft_delete'),
                          onPressed: () => _delete(e),
                        ),
                        onTap: () => _open(e),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Format ringkas "Rp 16.000" untuk subtitle daftar draft.
String _rp(num v) {
  final neg = v < 0;
  final s = v.abs().toInt().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp ${neg ? '-' : ''}$buf';
}
