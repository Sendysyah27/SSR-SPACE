import 'package:flutter/material.dart';
import 'package:ssr_space/services/ai_draft.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/theme/app_theme.dart';
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
  const AiDraftScreen({super.key, required this.initial});

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

  void _use() {
    final items = <ReceiptItem>[];
    final strs = <String>[];
    for (final r in _rows) {
      final name = r.name.text.trim();
      if (name.isEmpty) continue;
      var qty = int.tryParse(r.qty.text.trim()) ?? 1;
      if (qty < 1 || qty > 99) qty = 1;
      final price = _num(r.price.text) ?? 0;
      items.add(ReceiptItem(name: name, qty: qty, price: price));
      strs.add(
        qty > 1
            ? '$name x$qty ${price.toInt()}'
            : '$name ${price.toInt()}',
      );
    }
    var date = dateC.text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) date = '';
    final total = _num(totalC.text);
    Navigator.of(context).pop(
      ReceiptData(
        amount: total,
        date: date.isEmpty ? null : DateTime.tryParse(date),
        merchant: merchantC.text.trim().isEmpty
            ? null
            : merchantC.text.trim(),
        items: strs,
        lineItems: items,
        confident: total != null && total > 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('ai_review_t'))),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          _HeadCard(
            merchantC: merchantC,
            dateC: dateC,
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
          _TotalsCard(subC: subC, taxC: taxC, totalC: totalC),
          const SizedBox(height: SsrSpace.lg),
          PrimaryButton(label: tr('ai_use'), onPressed: _use),
          const SizedBox(height: SsrSpace.sm),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class _HeadCard extends StatelessWidget {
  final TextEditingController merchantC;
  final TextEditingController dateC;
  final TextEditingController payC;
  const _HeadCard({
    required this.merchantC,
    required this.dateC,
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
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
                  icon: const Icon(Icons.delete_outline),
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
  final TextEditingController taxC;
  final TextEditingController totalC;
  const _TotalsCard({
    required this.subC,
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
