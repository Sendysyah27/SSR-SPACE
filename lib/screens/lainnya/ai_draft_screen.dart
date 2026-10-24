import 'package:flutter/material.dart';
import 'package:ssr_space/services/ai_draft.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/labeled_section_card.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';

class _RowEdit {
  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController price;
  _RowEdit({String n = '', String q = '1', String p = ''})
      : name = TextEditingController(text: n),
        qty = TextEditingController(text: q),
        price = TextEditingController(text: p);
  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
  }
}

/// Review draft AI: semua field bisa dikoreksi sebelum dipakai.
/// Kembali null = buang; ReceiptData = pakai (prefill form).
class AiDraftScreen extends StatefulWidget {
  final AiDraft initial;

  /// Hasil parse asal (batch 286): field yang tak tampil di review
  /// (alamat, kasir, nomor struk, detail mentah, kurs asing)
  /// dipertahankan saat draft dipakai — tidak dibuang diam-diam.
  final ReceiptData? carry;

  /// Bila diisi, tombol "Simpan draft" tampil; callback menerima
  /// draft persis seperti yang sedang tampil di form.
  final Future<void> Function(AiDraft draft)? onSaveDraft;

  /// Dipanggil saat user menekan "Buang" (mis. menghapus entri draft
  /// tersimpan yang sedang dibuka).
  final VoidCallback? onDiscard;

  const AiDraftScreen({
    super.key,
    required this.initial,
    this.carry,
    this.onSaveDraft,
    this.onDiscard,
  });

  @override
  State<AiDraftScreen> createState() => AiDraftScreenState();
}

class AiDraftScreenState extends State<AiDraftScreen> {
  late TextEditingController merchantC;
  late TextEditingController dateC;
  late TextEditingController subC;
  late TextEditingController taxC;
  late TextEditingController totalC;
  late TextEditingController payC;
  late TextEditingController timeC;
  late TextEditingController discC;
  bool _saving = false;
  final List<_RowEdit> _rows = [];

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    merchantC = TextEditingController(text: d.merchant ?? '');
    dateC = TextEditingController(text: d.date ?? '');
    subC = TextEditingController(
      text: d.subtotal == null ? '' : d.subtotal!.toInt().toString(),
    );
    taxC = TextEditingController(
      text: d.tax == null ? '' : d.tax!.toInt().toString(),
    );
    totalC = TextEditingController(
      text: d.total == null ? '' : d.total!.toInt().toString(),
    );
    payC = TextEditingController(text: d.payment ?? '');
    timeC = TextEditingController(text: d.time ?? '');
    discC = TextEditingController(
      text: d.discount == null ? '' : d.discount!.toInt().toString(),
    );
    for (final it in d.items) {
      _rows.add(
        _RowEdit(
          n: it.name,
          q: '${it.qty}',
          p: it.price > 0 ? it.price.toInt().toString() : '',
        ),
      );
    }
  }

  @override
  void dispose() {
    merchantC.dispose();
    dateC.dispose();
    subC.dispose();
    taxC.dispose();
    totalC.dispose();
    payC.dispose();
    timeC.dispose();
    discC.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  double? _num(String s) {
    final v = double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (v == null || v < 0) return null;
    return v;
  }

  /// Draft persis seperti yang sedang tampil di form — satu sumber
  /// kebenaran untuk tombol Pakai & Simpan Draft (batch 286).
  AiDraft _currentDraft() {
    final items = <AiDraftItem>[];
    for (final r in _rows) {
      final name = r.name.text.trim();
      if (name.isEmpty) continue;
      var qty = int.tryParse(r.qty.text.trim()) ?? 1;
      if (qty < 1 || qty > 99) qty = 1;
      items.add(
        AiDraftItem(name: name, qty: qty, price: _num(r.price.text) ?? 0),
      );
    }
    var date = dateC.text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) date = '';
    final ts = timeC.text.trim();
    return AiDraft(
      merchant: merchantC.text.trim().isEmpty ? null : merchantC.text.trim(),
      date: date.isEmpty ? null : date,
      time: RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$').hasMatch(ts) ? ts : null,
      items: items,
      subtotal: _num(subC.text),
      tax: _num(taxC.text),
      discount: _num(discC.text),
      total: _num(totalC.text),
      payment: payC.text.trim().isEmpty ? null : payC.text.trim(),
    );
  }

  void _use() {
    var out = _currentDraft().toReceiptData();
    final c = widget.carry;
    if (c != null) {
      out = out.copyWith(
        address: c.address,
        cashier: c.cashier,
        phone: c.phone,
        receiptNo: c.receiptNo,
        detailText: c.detailText,
        fxCurrency: c.fxCurrency,
        fxOriginal: c.fxOriginal,
        fxRate: c.fxRate,
        dateFromReceipt: c.dateFromReceipt,
      );
    }
    Navigator.of(context).pop(out);
  }

  Future<void> _saveDraft() async {
    final cb = widget.onSaveDraft;
    if (cb == null || _saving) return;
    setState(() => _saving = true);
    await cb(_currentDraft());
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DribTokens.bgOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr('ai_review_t'),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          _HeadCard(
            merchantC: merchantC,
            dateC: dateC,
            timeC: timeC,
            payC: payC,
          ),
          const SizedBox(height: SsrSpace.md),
          _ItemsCard(
            rows: _rows,
            onAdd: () => setState(() => _rows.add(_RowEdit())),
            onDel: (i) => setState(() {
              _rows[i].dispose();
              _rows.removeAt(i);
            }),
          ),
          const SizedBox(height: SsrSpace.md),
          _TotalsCard(subC: subC, discC: discC, taxC: taxC, totalC: totalC),
          const SizedBox(height: SsrSpace.lg),
          PrimaryButton(label: tr('ai_use'), onPressed: _use),
          if (widget.onSaveDraft != null) ...[
            const SizedBox(height: SsrSpace.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _saving ? null : _saveDraft,
                style: OutlinedButton.styleFrom(
                  foregroundColor: DribTokens.primaryStrong,
                  side: const BorderSide(color: DribTokens.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(tr('scan_draft_save')),
              ),
            ),
          ],
          const SizedBox(height: SsrSpace.sm),
          Center(
            child: TextButton(
              onPressed: () {
                widget.onDiscard?.call();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: DribTokens.errorText,
              ),
              child: Text(tr('ai_discard')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboard;
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SsrSpace.sm),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: DribTokens.cardOf(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SsrRadius.input),
            borderSide: const BorderSide(color: DribTokens.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SsrRadius.input),
            borderSide: const BorderSide(color: DribTokens.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SsrRadius.input),
            borderSide: const BorderSide(
              color: DribTokens.primaryStrong,
              width: 1.5,
            ),
          ),
          isDense: true,
        ),
      ),
    );
  }
}

class _HeadCard extends StatelessWidget {
  final TextEditingController merchantC;
  final TextEditingController dateC;
  final TextEditingController timeC;
  final TextEditingController payC;
  const _HeadCard({
    required this.merchantC,
    required this.dateC,
    required this.timeC,
    required this.payC,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          _Field(controller: merchantC, hint: tr('ai_merchant')),
          _Field(
            controller: dateC,
            hint: tr('ai_date'),
            keyboard: TextInputType.datetime,
          ),
          _Field(
            controller: timeC,
            hint: tr('ai_time'),
            keyboard: TextInputType.datetime,
          ),
          _Field(controller: payC, hint: tr('ai_payment')),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final List<_RowEdit> rows;
  final VoidCallback onAdd;
  final void Function(int) onDel;
  const _ItemsCard({
    required this.rows,
    required this.onAdd,
    required this.onDel,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('ai_items'),
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: SsrSpace.sm),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: rows[i].name,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: DribTokens.cardOf(context),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(SsrRadius.input),
                        borderSide:
                            const BorderSide(color: DribTokens.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(SsrRadius.input),
                        borderSide:
                            const BorderSide(color: DribTokens.border),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: SsrSpace.xs),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: rows[i].qty,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: DribTokens.cardOf(context),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(SsrRadius.input),
                        borderSide:
                            const BorderSide(color: DribTokens.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(SsrRadius.input),
                        borderSide:
                            const BorderSide(color: DribTokens.border),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: SsrSpace.xs),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: rows[i].price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onDel(i),
                  icon: const Icon(Icons.delete_outline, color: DribTokens.errorText),
                  tooltip: tr('tx_delete'),
                ),
              ],
            ),
          ),
        TextButton(onPressed: onAdd, child: Text(tr('ai_add_item'))),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final TextEditingController subC;
  final TextEditingController discC;
  final TextEditingController taxC;
  final TextEditingController totalC;
  const _TotalsCard({
    required this.subC,
    required this.discC,
    required this.taxC,
    required this.totalC,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          _Field(
            controller: subC,
            hint: tr('rcp_subtotal'),
            keyboard: TextInputType.number,
          ),
          _Field(
            controller: discC,
            hint: tr('rcp_discount'),
            keyboard: TextInputType.number,
          ),
          _Field(
            controller: taxC,
            hint: tr('ai_tax'),
            keyboard: TextInputType.number,
          ),
          _Field(
            controller: totalC,
            hint: tr('rcp_total'),
            keyboard: TextInputType.number,
          ),
        ],
      ),
    );
  }
}
