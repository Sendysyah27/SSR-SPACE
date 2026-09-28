// E-Money NFC: daftar kartu tertaut + tempel-baca + histori cek lokal.
// Read-only: tanpa top-up, tanpa transaksi otomatis, tanpa migration.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/services/nfc_emoney.dart';
import 'package:ssr_space/services/nfc_emoney_logic.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';

class NfcCardsScreen extends StatefulWidget {
  const NfcCardsScreen({super.key});

  @override
  State<NfcCardsScreen> createState() => _NfcCardsScreenState();
}

class _NfcCardsScreenState extends State<NfcCardsScreen> {
  bool loading = true;
  bool scanning = false;
  List<NfcCard> cards = [];
  List<NfcCheck> checks = [];
  List<Wallet> wallets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    List<Wallet> ws = [];
    try {
      final orgId = prefs.getString('active_org_id') ?? '';
      if (orgId.isNotEmpty) ws = await WalletService().list(orgId);
    } catch (e) {
      debugPrint('nfc wallets: $e');
    }
    final cs = await loadNfcCards();
    final hs = await loadNfcChecks();
    if (!mounted) return;
    setState(() {
      wallets = ws;
      cards = cs;
      checks = hs;
      loading = false;
    });
  }

  String _walletName(String? id) {
    if (id == null || id.isEmpty) return tr('nfc_no_wallet');
    for (final w in wallets) {
      if (w.id == id) return w.name;
    }
    return tr('nfc_no_wallet');
  }

  Future<void> _scan() async {
    if (scanning) return;
    setState(() => scanning = true);
    final read = await nfcReadCard();
    if (!mounted) return;
    setState(() => scanning = false);
    if (!read.ok || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('nfc_read_fail'))),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ResultSheet(
        read: read,
        wallets: wallets,
        onSave: _save,
      ),
    );
  }

  Future<void> _save(NfcCardRead read, String? walletId) async {
    final now = DateTime.now().toIso8601String();
    final num = read.number.trim();
    final card = NfcCard(
      uid: read.uid,
      bank: read.bank,
      last4: num.length >= 4 ? num.substring(num.length - 4) : '',
      label: '${read.bank} •• ${num.length >= 4 ? num.substring(num.length - 4) : ''}',
      walletId: (walletId == null || walletId.isEmpty) ? null : walletId,
      addedAt: now,
    );
    final all = await loadNfcCards();
    all.removeWhere((c) => c.uid == card.uid);
    all.insert(0, card);
    await saveNfcCards(all);
    if (read.balance != null) {
      await addNfcCheck(NfcCheck(
        uid: read.uid,
        bank: read.bank,
        balance: read.balance!,
        at: now,
      ));
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('nfc_saved'))),
    );
  }

  Future<void> _remove(NfcCard card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('nfc_delete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('tx_delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final all = await loadNfcCards();
    all.removeWhere((c) => c.uid == card.uid);
    await saveNfcCards(all);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('nfc_title'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(SsrSpace.lg),
              children: [
                _ScanCard(scanning: scanning, onTap: _scan, onStop: nfcStop),
                _CardsCard(
                  cards: cards,
                  walletName: _walletName,
                  onRemove: _remove,
                ),
                _ChecksCard(checks: checks),
              ],
            ),
    );
  }
}

// Kartu pindai: status + tombol tempel/stop + indikator saat scanning.
class _ScanCard extends StatelessWidget {
  final bool scanning;
  final VoidCallback onTap;
  final Future<void> Function() onStop;

  const _ScanCard({
    required this.scanning,
    required this.onTap,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('nfc_lib_ready')),
          const SizedBox(height: SsrSpace.sm),
          FilledButton(
            onPressed: scanning ? null : onTap,
            child: Text(tr('nfc_tap')),
          ),
          const SizedBox(height: SsrSpace.sm),
          OutlinedButton(
            onPressed: scanning ? onStop : null,
            child: Text(tr('nfc_stop')),
          ),
          if (scanning) ...[
            const SizedBox(height: SsrSpace.sm),
            const LinearProgressIndicator(),
            const SizedBox(height: SsrSpace.sm),
            Text(tr('nfc_scanning')),
          ],
        ],
      ),
    );
  }
}

// Kartu daftar: satu ListTile per kartu tersimpan + hapus.
class _CardsCard extends StatelessWidget {
  final List<NfcCard> cards;
  final String Function(String?) walletName;
  final Future<void> Function(NfcCard) onRemove;

  const _CardsCard({
    required this.cards,
    required this.walletName,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: cards.isEmpty
          ? Text(tr('nfc_empty'))
          : Column(
              children: [
                for (final card in cards)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(card.label),
                    subtitle: Text(
                      '•••• ${card.last4} · ${card.bank} · '
                      '${walletName(card.walletId)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onRemove(card),
                    ),
                  ),
              ],
            ),
    );
  }
}

// Kartu cek terakhir: baris saldo + waktu + bank. Kosong → sembunyi.
class _ChecksCard extends StatelessWidget {
  final List<NfcCheck> checks;

  const _ChecksCard({required this.checks});

  String _when(String at) => at.length >= 16 ? at.substring(0, 16) : at;

  @override
  Widget build(BuildContext context) {
    if (checks.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('nfc_checks'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: SsrSpace.sm),
          for (final c in checks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${c.bank} · ${_when(c.at)}'),
                  ),
                  Text(amt(c.balance)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Sheet hasil baca: saldo + taut dompet + histori kartu + simpan.
class _ResultSheet extends StatefulWidget {
  final NfcCardRead read;
  final List<Wallet> wallets;
  final Future<void> Function(NfcCardRead, String?) onSave;

  const _ResultSheet({
    required this.read,
    required this.wallets,
    required this.onSave,
  });

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  String? _walletId;

  String _dirLabel(NfcEntryDir dir) {
    return switch (dir) {
      NfcEntryDir.credit => tr('nfc_in'),
      NfcEntryDir.debit => tr('nfc_out'),
      NfcEntryDir.unknown => tr('nfc_other'),
    };
  }

  List<Widget> _historyRows() {
    final entries = widget.read.entries;
    final shown = entries.length <= 11 ? entries : entries.sublist(0, 11);
    return [
      for (final e in shown)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text('${_dirLabel(e.dir)} · ${e.date}')),
              Text(amt(e.amount)),
            ],
          ),
        ),
    ];
  }

  Future<void> _onSave() async {
    await widget.onSave(widget.read, _walletId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('nfc_balance')),
            Text(
              widget.read.balance == null ? '-' : amt(widget.read.balance!),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(widget.read.bank),
            const SizedBox(height: SsrSpace.md),
            DropdownButtonFormField<String?>(
              value: _walletId,
              hint: Text(tr('nfc_link')),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(tr('nfc_no_wallet')),
                ),
                for (final w in widget.wallets)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _walletId = v),
            ),
            const SizedBox(height: SsrSpace.md),
            Text(
              tr('nfc_card_history'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: SsrSpace.sm),
            ..._historyRows(),
            const SizedBox(height: SsrSpace.md),
            FilledButton(
              onPressed: _onSave,
              child: Text(tr('nfc_save')),
            ),
          ],
        ),
      ),
    );
  }
}
