import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/month.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';
import 'package:ssr_space/core/saas/tx_validation.dart';
import 'package:ssr_space/core/saas/wallet_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';
import 'package:ssr_space/widgets/month_picker.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/tx_row.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionsScreen extends StatefulWidget {
  final String? initialMonth;
  const TransactionsScreen({super.key, this.initialMonth});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late String month;
  List<SaasTransaction> items = [];
  List<Wallet> wallets = [];
  List<WalletBalance> balances = [];
  SaasTransaction? editing;
  DateTime? editDate;
  final formKey = GlobalKey();
  bool noOrg = false;
  bool loading = true;
  bool saving = false;
  String? err;
  String? formErr;
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  final catC = TextEditingController();
  String type = 'out';
  String? walletId;
  String? toWalletId;

  @override
  void initState() {
    super.initState();
    month = widget.initialMonth ?? currentMonth();
    _load();
  }

  Future<String> _orgId() async =>
      (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await _orgId();
      if (orgId.isEmpty) {
        setState(() {
          noOrg = true;
          loading = false;
        });
        return;
      }
      final w = await WalletService().list(orgId);
      List<WalletBalance> bals = [];
      try {
        bals = await WalletService().balances(orgId);
      } catch (_) {
        bals = [];
      }
      final t = await TransactionService().listMonth(orgId, month);
      if (!mounted) return;
      setState(() {
        noOrg = false;
        wallets = w;
        balances = bals;
        items = t;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = 'Gagal memuat transaksi. Periksa koneksi.';
      });
    }
  }

  double? _balanceOf(String? id) {
    if (id == null) return null;
    for (final b in balances) {
      if (b.walletId == id) return b.balance;
    }
    return null;
  }

  void _startEdit(SaasTransaction t) {
    setState(() {
      editing = t;
      type = t.type;
      amountC.text = t.amount.toStringAsFixed(0);
      catC.text = t.category ?? '';
      noteC.text = t.note ?? '';
      walletId = t.walletId;
      toWalletId = t.toWalletId;
      editDate = t.date == null ? null : DateTime.tryParse(t.date!);
      formErr = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = formKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: SsrMotion.base,
          curve: SsrMotion.curve,
        );
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      editing = null;
      editDate = null;
      type = 'out';
      amountC.clear();
      noteC.clear();
      catC.clear();
      walletId = null;
      toWalletId = null;
      formErr = null;
    });
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final nominal = double.tryParse(amountC.text);
    if (nominal == null) {
      setState(() => formErr = 'Isi nominal dengan angka yang benar.');
      return;
    }
    final v = validateTxInput(
      amount: nominal,
      walletId: walletId,
      type: type,
      toWalletId: toWalletId,
    );
    if (v != null) {
      setState(() => formErr = v);
      return;
    }
    setState(() {
      saving = true;
      formErr = null;
    });
    try {
      final orgId = await _orgId();
      final cat = catC.text.trim().isEmpty ? null : catC.text.trim();
      final note = noteC.text.trim();
      final svc = TransactionService();
      if (editing != null) {
        await svc.update(
          id: editing!.id,
          orgId: orgId,
          type: type,
          amount: nominal,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note.isEmpty ? null : note,
          date: editDate == null ? editing!.date : _ymd(editDate!),
        );
        if (!mounted) return;
        _cancelEdit();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaksi diperbarui')));
      } else {
        await svc.add(
          orgId: orgId,
          type: type,
          amount: nominal,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note,
        );
        if (!mounted) return;
        amountC.clear();
        noteC.clear();
        catC.clear();
        setState(() {
          walletId = null;
          toWalletId = null;
        });
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      debugPrint('save tx: $e');
      setState(() => formErr = _txError(e, 'menyimpan'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _txError(Object e, String action) {
    if (e is PostgrestException) {
      switch (e.code) {
        case '42501':
          return 'Tidak punya akses ke workspace ini.';
        case '23503':
          return 'Dompet tidak valid. Muat ulang lalu pilih lagi.';
        case '23514':
          return 'Data tidak lolos validasi server.';
        case '23505':
          return 'Transaksi duplikat sudah tercatat.';
        case 'PGRST116':
          return 'Gagal $action: respons server tidak valid.';
        default:
          return 'Gagal $action (${e.code ?? 'error'}). Coba lagi.';
      }
    }
    return 'Gagal $action. Coba lagi.';
  }

  Future<void> _confirmDelete() async {
    if (editing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi'),
        content: const Text('Hapus transaksi ini? Tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || editing == null) return;
    try {
      final orgId = await _orgId();
      await TransactionService().delete(editing!.id, orgId);
      if (!mounted) return;
      _cancelEdit();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Transaksi dihapus')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      debugPrint('delete tx: $e');
      setState(() => formErr = _txError(e, 'menghapus'));
    }
  }

  DropdownMenuItem<String> _walletItem(Wallet w, ThemeData theme) {
    final bal = _balanceOf(w.id);
    return DropdownMenuItem(
      value: w.id,
      child: Text(
        bal == null ? w.name : '${w.name} · ${rp(bal)}',
        style: bal == null
            ? null
            : theme.textTheme.bodyMedium?.copyWith(
                color: SsrColors.secondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
      ),
    );
  }

  void _scrollToForm() {
    final ctx = formKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: SsrMotion.base,
        curve: SsrMotion.curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (noOrg) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaksi')),
        body: EmptyView(
          icon: Icons.business_outlined,
          title: 'Belum ada workspace',
          subtitle: 'Pilih atau buat workspace dulu di menu Lainnya.',
          actionLabel: 'Muat ulang',
          onAction: _load,
        ),
      );
    }
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaksi')),
        body: const LoadingView(label: 'Memuat transaksi...'),
      );
    }
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaksi')),
        body: ErrorView(message: err!, onRetry: _load),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SsrSpace.lg,
          SsrSpace.lg,
          SsrSpace.lg,
          96,
        ),
        children: [
          MonthPicker(
            month: month,
            onChanged: (m) {
              setState(() => month = m);
              _load();
            },
          ),
          const SizedBox(height: SsrSpace.md),
          SectionCard(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (editing != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(SsrSpace.md),
                    decoration: BoxDecoration(
                      color: SsrColors.accentSoft,
                      borderRadius: BorderRadius.circular(SsrRadius.tile),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Mengubah ${editing!.code ?? 'transaksi'}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _cancelEdit,
                          child: const Text('Batalkan edit'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SsrSpace.md),
                ],
                Text(
                  editing != null ? 'Mengubah transaksi' : 'Catat transaksi',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: SsrSpace.md),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'in', label: Text('Masuk')),
                    ButtonSegment(value: 'out', label: Text('Keluar')),
                    ButtonSegment(value: 'transfer', label: Text('Transfer')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setState(() => type = v.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return SsrColors.accent;
                      }
                      return Colors.white;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return SsrColors.ink;
                    }),
                    side: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const BorderSide(color: SsrColors.accent);
                      }
                      return BorderSide(color: theme.colorScheme.outline);
                    }),
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: SsrSpace.lg),
                TextField(
                  controller: amountC,
                  keyboardType: TextInputType.number,
                  style: SsrTheme.moneyLarge,
                  decoration: const InputDecoration(
                    labelText: 'Nominal',
                    prefixText: 'Rp ',
                    prefixStyle: SsrTheme.moneyLarge,
                  ),
                ),
                const SizedBox(height: SsrSpace.md),
                TextField(
                  controller: catC,
                  decoration: const InputDecoration(
                    labelText: 'Kategori (misal Makan)',
                  ),
                ),
                const SizedBox(height: SsrSpace.md),
                TextField(
                  controller: noteC,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
                const SizedBox(height: SsrSpace.md),
                DropdownButtonFormField<String>(
                  value: walletId,
                  decoration: const InputDecoration(labelText: 'Dompet'),
                  items: [for (final w in wallets) _walletItem(w, theme)],
                  onChanged: (v) => setState(() => walletId = v),
                ),
                if (type == 'transfer') ...[
                  const SizedBox(height: SsrSpace.md),
                  DropdownButtonFormField<String>(
                    value: toWalletId,
                    decoration: const InputDecoration(
                      labelText: 'Dompet tujuan',
                    ),
                    items: [for (final w in wallets) _walletItem(w, theme)],
                    onChanged: (v) => setState(() => toWalletId = v),
                  ),
                ],
                if (formErr != null) ...[
                  const SizedBox(height: SsrSpace.md),
                  Text(
                    formErr!,
                    style: const TextStyle(
                      color: SsrColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: SsrSpace.lg),
                PrimaryButton(
                  label: editing != null
                      ? 'Simpan perubahan'
                      : 'Simpan transaksi',
                  onPressed: _save,
                  loading: saving,
                ),
                if (editing != null) ...[
                  const SizedBox(height: SsrSpace.sm),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _confirmDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SsrColors.danger,
                        side: const BorderSide(color: SsrColors.danger),
                      ),
                      child: const Text('Hapus'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: SsrSpace.xl),
          Text(
            'Riwayat ${monthLabel(month).toLowerCase()}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: SsrSpace.sm),
          if (items.isEmpty)
            SizedBox(
              height: 260,
              child: EmptyView(
                icon: Icons.receipt_long_outlined,
                title: 'Belum ada transaksi bulan ini',
                subtitle:
                    'Catat pemasukan atau pengeluaran lewat form di atas.',
                actionLabel: 'Isi form catat',
                onAction: _scrollToForm,
              ),
            )
          else
            for (final t in items) ...[
              TxRow(
                tx: t,
                selected: editing?.id == t.id,
                onTap: () => _startEdit(t),
              ),
              const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}
