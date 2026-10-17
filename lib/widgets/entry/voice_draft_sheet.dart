import 'package:flutter/material.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/services/category_icons.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/entry/ollo_entry_sheet.dart';
import 'package:ssr_space/widgets/entry/voice_listening_sheet.dart';

/// Hasil urai suara menjadi draft transaksi (nominal dalam IDR).
/// Adapter tipis di atas [QuickInput]: tak bikin model duplikat, hanya
/// menambah judul + waktu untuk layar review.
class VoiceDraft {
  final double amount;
  final String type; // 'in' | 'out'
  final String? category;
  final String? walletName;
  final String title;
  final String note;
  final DateTime dateTime;

  const VoiceDraft({
    required this.amount,
    required this.type,
    this.category,
    this.walletName,
    required this.title,
    this.note = '',
    required this.dateTime,
  });
}

/// Alur suara gaya Ollo: listening -> draft review -> simpan.
/// true bila tersimpan (pemanggil boleh muat ulang).
Future<bool> openOlloVoiceFlow(BuildContext context) async {
  final draft = await showVoiceListeningSheet(context);
  if (draft == null || !context.mounted) return false;
  return showVoiceDraftSheet(context, draft);
}

/// Layar "Draft Siap" gaya Ollo: ringkasan hasil tangkapan suara +
/// tombol Edit (buka entry sheet prefilled) & Simpan (jalur simpan tunggal).
/// true bila tersimpan.
Future<bool> showVoiceDraftSheet(BuildContext context, VoiceDraft draft) async {
  var saved = false;
  var edited = false;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VoiceDraftSheet(
      draft: draft,
      onSaved: () => saved = true,
      onEdit: () => edited = true,
    ),
  );
  if (edited && context.mounted) {
    await showOlloEntrySheet(context, initialDraft: draft);
    return true;
  }
  return saved;
}

class _VoiceDraftSheet extends StatefulWidget {
  final VoiceDraft draft;
  final VoidCallback onSaved;
  final VoidCallback onEdit;
  const _VoiceDraftSheet({
    required this.draft,
    required this.onSaved,
    required this.onEdit,
  });

  @override
  State<_VoiceDraftSheet> createState() => _VoiceDraftSheetState();
}

class _VoiceDraftSheetState extends State<_VoiceDraftSheet> {
  List<Wallet> _wallets = const [];
  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty || !mounted) return;
      final ws = await WalletService().list(orgId);
      if (mounted) setState(() => _wallets = ws);
    } catch (_) {}
  }

  String? _resolveWalletId() {
    if (_wallets.isEmpty) return null;
    final wn = widget.draft.walletName?.trim().toLowerCase();
    if (wn != null && wn.isNotEmpty) {
      for (final w in _wallets) {
        if (w.name.toLowerCase() == wn) return w.id;
      }
    }
    return _wallets.first.id;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _err = null;
    });
    final orgId = await activeOrgId();
    String? err;
    if (orgId.isEmpty) {
      err = tr('vc_error');
    } else {
      final d = widget.draft;
      err = await persistOlloTx(
        orgId: orgId,
        type: d.type,
        amountIdr: d.amount,
        walletId: _resolveWalletId(),
        category: d.category,
        title: d.title,
        note: d.note,
        day: DateTime(d.dateTime.year, d.dateTime.month, d.dateTime.day),
      );
    }
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _err = err;
      });
      return;
    }
    widget.onSaved();
    Navigator.of(context).pop();
  }

  Widget _circle(IconData icon, Color color) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 26, color: color),
    );
  }

  Widget _row(ColorScheme scheme, String label, String value,
      {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = widget.draft;
    final catColor =
        metaSlotColor(context, (d.category ?? '').hashCode.abs() % 12);
    final dt = d.dateTime;
    final ymd =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    const walletBlue = Color(0xFF5B9BF5);

    return Container(
      decoration: BoxDecoration(
        color: DribTokens.cardOf(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DribTokens.sheetRadius),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: scheme.outlineVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('voice_draft_title'),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circle(AppIcons.wallet, walletBlue),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
              ),
              _circle(iconForCategory(d.category), catColor),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _row(scheme, tr('voice_d_title'),
                      d.title.isEmpty ? '-' : d.title,
                      strong: true),
                  _row(scheme, tr('voice_d_amount'), amt(d.amount),
                      strong: true),
                  _row(scheme, tr('voice_d_datetime'),
                      txWhenLabel(ymd, dt.toIso8601String())),
                  _row(scheme, tr('voice_d_wallet'),
                      d.walletName ?? '-'),
                  _row(scheme, tr('voice_d_category'),
                      d.category ?? '-'),
                  _row(scheme, tr('voice_d_subcategory'), '-'),
                  _row(scheme, tr('voice_d_type'),
                      d.type == 'in' ? tr('tx_in') : tr('tx_out')),
                  _row(scheme, tr('voice_d_note'),
                      d.note.isEmpty ? '-' : d.note),
                ],
              ),
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 8),
            Text(
              _err!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _saving
                      ? null
                      : () {
                          widget.onEdit();
                          Navigator.of(context).pop();
                        },
                  child: Text(tr('voice_d_edit'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.inverseSurface,
                    foregroundColor: scheme.onInverseSurface,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(tr('voice_d_save'),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
