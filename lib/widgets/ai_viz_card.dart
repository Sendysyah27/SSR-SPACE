import 'package:flutter/material.dart';

import 'package:ssr_space/services/ai_assistant_context.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';

// Kartu visualisasi Mode Asisten (batch 281C tahap 2, diekstraksi dari
// ai_chat_screen.dart batch 285 tahap C): angka SELALU dari snapshot
// lokal app; model hanya memilih jenis kartu. Viz tanpa data pendukung
// dirender sebagai widget kosong (aman).
//
// Batch 285 tahap C menambah 4 jenis kartu (pola VisualizationBuilder
// Ollo): banding_periode, tren_30, top_merchant, progres_target.

/// Selisih persen cur vs prev, bertanda: '+12%', '-8%', atau '—' bila
/// tak bisa dihitung. Murni (testable).
String vizDeltaPct(double cur, double prev) {
  if (prev <= 0) return cur > 0 ? 'baru' : '—';
  final pct = ((cur - prev) / prev * 100).round();
  return '${pct >= 0 ? '+' : ''}$pct%';
}

class AiVizCard extends StatelessWidget {
  final Map<String, dynamic> viz;
  final AssistantSnapshot data;
  const AiVizCard({super.key, required this.viz, required this.data});

  String _amt(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = viz['type'] as String? ?? '';
    var title = '';
    final rows = <Widget>[];
    if (type == 'saldo') {
      title = tr('ai_viz_saldo');
      for (final w in data.wallets) {
        rows.add(_VizRow(label: w.name, value: _amt(w.balance)));
      }
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 12));
        rows.add(_VizRow(
            label: tr('ai_viz_total'),
            value: _amt(data.totalBalance),
            bold: true));
      }
    } else if (type == 'rincian_kategori') {
      title = tr('ai_viz_kategori');
      final limit = (viz['limit'] as int?) ?? 5;
      final cats = data.topCategories.take(limit).toList();
      final max = cats.isEmpty ? 0.0 : cats.first.total;
      for (final c in cats) {
        rows.add(_VizRow(label: c.name, value: _amt(c.total)));
        rows.add(_VizBar(
            frac: max > 0 ? c.total / max : 0, color: scheme.primary));
      }
    } else if (type == 'tren_ringkas') {
      title = tr('ai_viz_tren');
      var max = 0.0;
      for (final d in data.last7) {
        if (d.outAmt > max) max = d.outAmt;
      }
      for (final d in data.last7) {
        final lbl = d.day.length >= 10 ? d.day.substring(5) : d.day;
        rows.add(_VizRow(
            label: lbl, value: '-${_amt(d.outAmt)} / +${_amt(d.inAmt)}'));
        rows.add(_VizBar(
            frac: max > 0 ? d.outAmt / max : 0, color: scheme.primary));
      }
    } else if (type == 'banding_periode') {
      // Dua kolom: bulan ini vs bulan lalu (masuk/keluar + selisih %).
      title = tr('ai_viz_banding');
      rows.add(_VizTwoCol(
        leftHead: tr('ai_viz_ini'),
        rightHead: tr('ai_viz_lalu'),
        left: [
          '${tr('ai_viz_masuk')}: ${_amt(data.monthIn)}',
          '${tr('ai_viz_keluar')}: ${_amt(data.monthOut)}',
        ],
        right: [
          '${tr('ai_viz_masuk')}: ${_amt(data.prevMonthIn)}',
          '${tr('ai_viz_keluar')}: ${_amt(data.prevMonthOut)}',
        ],
      ));
      rows.add(_VizRow(
        label: 'Δ ${tr('ai_viz_masuk')}',
        value: vizDeltaPct(data.monthIn, data.prevMonthIn),
        bold: true,
      ));
      rows.add(_VizRow(
        label: 'Δ ${tr('ai_viz_keluar')}',
        value: vizDeltaPct(data.monthOut, data.prevMonthOut),
        bold: true,
      ));
    } else if (type == 'tren_30') {
      // Batang mini 30 hari dari data snapshot (tanpa chart library).
      title = tr('ai_viz_tren30');
      var max = 0.0;
      var total = 0.0;
      for (final d in data.daily30) {
        total += d.outAmt;
        if (d.outAmt > max) max = d.outAmt;
      }
      if (data.daily30.isNotEmpty) {
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in data.daily30)
                Expanded(
                  child: Container(
                    height:
                        4 + 40 * (max > 0 ? d.outAmt / max : 0),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ));
        rows.add(_VizRow(
            label: '${tr('ai_viz_keluar')} · 30 hari', value: _amt(total), bold: true));
      }
    } else if (type == 'top_merchant') {
      title = tr('ai_viz_merchant');
      final merchants = data.topMerchants.take(5).toList();
      final max = merchants.isEmpty ? 0.0 : merchants.first.total;
      for (final m in merchants) {
        rows.add(_VizRow(label: m.name, value: _amt(m.total)));
        rows.add(_VizBar(
            frac: max > 0 ? m.total / max : 0, color: scheme.primary));
      }
    } else if (type == 'progres_target') {
      title = tr('ai_viz_target');
      final goals = data.goals.take(6).toList();
      for (final g in goals) {
        final pct = g.target > 0
            ? (g.saved / g.target * 100).round()
            : 0;
        rows.add(_VizRow(
            label: g.name, value: '${_amt(g.saved)}/${_amt(g.target)}'));
        rows.add(_VizBar(
            frac: g.target > 0
                ? (g.saved / g.target).clamp(0.0, 1.0)
                : 0,
            color: scheme.primary));
        rows.add(_VizRow(label: '', value: '$pct%'));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2, bottom: 4),
        padding: const EdgeInsets.all(SsrSpace.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: SsrSpace.sm),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _VizTwoCol extends StatelessWidget {
  final String leftHead;
  final String rightHead;
  final List<String> left;
  final List<String> right;
  const _VizTwoCol({
    required this.leftHead,
    required this.rightHead,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final head = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        );
    final body = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSecondaryContainer,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leftHead, style: head),
                for (final v in left) Text(v, style: body),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rightHead, style: head),
                for (final v in right) Text(v, style: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VizRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _VizRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _VizBar extends StatelessWidget {
  final double frac;
  final Color color;
  const _VizBar({required this.frac, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: frac.clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: color.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}
