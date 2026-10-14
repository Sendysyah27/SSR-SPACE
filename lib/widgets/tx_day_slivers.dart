import 'package:flutter/material.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/tx_day_group.dart';
import 'package:ssr_space/widgets/day_header.dart';

/// Slot render untuk daftar TxRow per-hari dalam satu SliverList.
/// Title/header TIDAK termasuk: render sebagai SliverToBoxAdapter terpisah
/// supaya judul tak ikut virtualisasi (tetap di atas, sama seperti dulu).
enum _SlotKind { header, row }

class _Slot {
  final _SlotKind kind;
  final DayBucket? bucket;
  final SaasTransaction? tx;
  final bool leadDivider;
  final bool trailDivider;

  const _Slot.header(this.bucket)
      : kind = _SlotKind.header,
        tx = null,
        leadDivider = false,
        trailDivider = false;

  const _Slot.row(this.tx,
      {required this.leadDivider, required this.trailDivider})
      : kind = _SlotKind.row,
        bucket = null;
}

/// Satu SliverList lazy untuk transaksi yang sudah dikelompokkan per hari.
/// [buildRow] bangun baris TxRow untuk satu transaksi (tanpa divider;
/// divider ditangani di sini agar posisi pixel-identik dengan Column lama).
/// [dividersBetween] true = divider hanya di antara baris (laporan, dompet);
/// false = divider setelah tiap baris termasuk terakhir bucket (transaksi).
Widget txDaySliverList({
  required List<SaasTransaction> items,
  required Widget Function(SaasTransaction tx) buildRow,
  bool dividersBetween = true,
}) {
  final slots = <_Slot>[];
  for (final b in groupDayBuckets(items)) {
    slots.add(_Slot.header(b));
    for (var i = 0; i < b.items.length; i++) {
      slots.add(_Slot.row(
        b.items[i],
        leadDivider: dividersBetween && i > 0,
        trailDivider: !dividersBetween,
      ));
    }
  }
  return SliverList(
    delegate: SliverChildBuilderDelegate(
      (context, i) {
        final s = slots[i];
        if (s.kind == _SlotKind.header) {
          return DayHeader(
            dateKey: s.bucket!.key,
            count: s.bucket!.items.length,
          );
        }
        // Glassmorphism: cards carry their own visual separation;
        // keep dividers only when caller explicitly wants the classic list look.
        if (s.leadDivider || s.trailDivider) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.leadDivider) const Divider(height: 1),
              buildRow(s.tx!),
              if (s.trailDivider) const Divider(height: 1),
            ],
          );
        }
        return buildRow(s.tx!);
      },
      childCount: slots.length,
    ),
  );
}
