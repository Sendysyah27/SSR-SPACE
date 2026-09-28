// E-Money NFC: daftar kartu tertaut + tempel-baca + histori cek lokal.
// Read-only: tanpa top-up, tanpa transaksi otomatis, tanpa migration.
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/services/nfc_emoney.dart';
import 'package:ssr_space/services/nfc_emoney_logic.dart';
import 'package:ssr_space/services/notif_parse.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';

String _last4(String n) {
  final t = n.trim();
  return t.length >= 4 ? t.substring(t.length - 4) : '';
}

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
  NFCAvailability? nfcAv;

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
    try {
      nfcAv = await FlutterNfcKit.nfcAvailability;
    } catch (e) {
      debugPrint('nfc avail: $e');
      nfcAv = null;
    }
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
    final wid = _linkedId(read.uid);
    if (wid == null) {
      await _showResult(read, wid: null, matched: false);
      return;
    }
    await _scanLinked(read, wid);
  }

  String? _linkedId(String uid) {
    for (final c in cards) {
      if (c.uid == uid) return c.walletId;
    }
    return null;
  }

  Future<void> _showResult(
    NfcCardRead read, {
    required String? wid,
    required bool matched,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ResultSheet(
        read: read,
        wallets: wallets,
        linkedWalletId: wid,
        matched: matched,
        onSave: _save,
        onMade: () async {
          await _load();
        },
      ),
    );
  }

  Future<void> _scanLinked(NfcCardRead read, String wid) async {
    final orgId = await activeOrgId();
    double? book;
    try {
      final bs = await WalletService().balances(orgId);
      for (final b in bs) {
        if (b.walletId == wid) {
          book = b.balance;
          break;
        }
      }
    } catch (e) {
      debugPrint('nfc book: $e');
    }
    if (book == null) {
      final all = await loadNfcCards();
      all.removeWhere((c) => c.uid == read.uid);
      await saveNfcCards(all);
      await _load();
      await _showResult(read, wid: null, matched: false);
      return;
    }
    if (!mounted) return;
    if (read.balance == null) {
      await _showResult(read, wid: wid, matched: false);
      return;
    }
    final adj = nfcAdjustmentFor(book: book, card: read.balance!);
    if (!mounted) return;
    if (adj == null) {
      await _showResult(read, wid: wid, matched: true);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AdjustSheet(
        read: read,
        walletId: wid,
        offer: adj,
        last4: _last4(read.number),
        orgId: orgId,
        onDone: _load,
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
                if (nfcAv == NFCAvailability.not_supported)
                  const _NoNfcCard()
                else ...[
                  if (nfcAv == NFCAvailability.disabled)
                    _NfcOffBanner(onRetry: _load),
                  _ScanCard(scanning: scanning, onTap: _scan, onStop: nfcStop),
                ],
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
class _NoNfcCard extends StatelessWidget {
  const _NoNfcCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Text(tr('nfc_no_hw')),
    );
  }
}

class _NfcOffBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _NfcOffBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('nfc_off'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(tr('nfc_off_steps')),
          const SizedBox(height: SsrSpace.sm),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(tr('nfc_retry')),
          ),
        ],
      ),
    );
  }
}

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
  final String? linkedWalletId;
  final Future<void> Function() onMade;
  final bool matched;

  const _ResultSheet({
    required this.read,
    required this.wallets,
    required this.onSave,
    required this.linkedWalletId,
    required this.onMade,
    required this.matched,
  });

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _BalanceHead extends StatelessWidget {
  final NfcCardRead read;
  final bool matched;

  const _BalanceHead({required this.read, required this.matched});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('nfc_balance')),
        Text(
          read.balance == null ? '-' : amt(read.balance!),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(read.bank),
        if (matched) ...[
          const SizedBox(height: SsrSpace.sm),
          Text(tr('nfc_matched')),
        ],
      ],
    );
  }
}

class _MakeWalletBtn extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _MakeWalletBtn({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onTap,
      child: Text(tr('nfc_make_wallet')),
    );
  }
}

class _ResultSheetState extends State<_ResultSheet> {
  String? _walletId;
  bool busy = false;

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

  Future<void> _make() async {
    setState(() => busy = true);
    try {
      final orgId = await activeOrgId();
      await linkCardAsWallet(
        orgId: orgId,
        bank: widget.read.bank,
        last4: _last4(widget.read.number),
        balance: widget.read.balance ?? 0,
        uid: widget.read.uid,
      );
      await widget.onMade();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('nfc_wallet_made'))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('nfc_read_fail'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BalanceHead(read: widget.read, matched: widget.matched),
            const SizedBox(height: SsrSpace.md),
            if (widget.linkedWalletId == null) ...[
              _MakeWalletBtn(busy: busy, onTap: _make),
              const SizedBox(height: SsrSpace.md),
            ],
            DropdownButtonFormField<String?>(
              initialValue: _walletId,
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

// Sheet tawar selisih: kartu tertaut tapi saldo beda vs buku.
class _AdjustSheet extends StatefulWidget {
  final NfcCardRead read;
  final String walletId;
  final ({String type, double amount}) offer;
  final String last4;
  final String orgId;
  final Future<void> Function() onDone;

  const _AdjustSheet({
    required this.read,
    required this.walletId,
    required this.offer,
    required this.last4,
    required this.orgId,
    required this.onDone,
  });

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  bool busy = false;

  Future<void> _record() async {
    setState(() => busy = true);
    try {
      await TransactionService().add(
        orgId: widget.orgId,
        type: widget.offer.type,
        amount: widget.offer.amount,
        walletId: widget.walletId,
        category: 'Penyesuaian',
        note: 'Penyesuaian NFC ${widget.read.bank} •• ${widget.last4}',
        date: ymd(DateTime.now()),
      );
      await widget.onDone();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('tx_updated'))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('nfc_read_fail'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('nfc_diff').replaceFirst('{m}', amt(widget.offer.amount)),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              widget.offer.type == 'in' ? tr('nfc_in') : tr('nfc_out'),
            ),
            const SizedBox(height: SsrSpace.md),
            FilledButton(
              onPressed: busy ? null : _record,
              child: Text(tr('rb_record')),
            ),
            const SizedBox(height: SsrSpace.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('rb_skip')),
            ),
          ],
        ),
      ),
    );
  }
}
