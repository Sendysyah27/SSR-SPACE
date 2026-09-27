import '../models/transaction.dart';

class DayBucket {
  final String key;
  final List<SaasTransaction> items;
  const DayBucket(this.key, this.items);
}

String _dayKey(SaasTransaction t) {
  final d = t.date ?? '';
  return d.length >= 10 ? d.substring(0, 10) : 'no-date';
}

/// Kelompokkan per hari kalender, key DESC, no-date paling bawah.
/// Isi tiap bucket urut createdAt DESC. Tidak memutasi input.
List<DayBucket> groupDayBuckets(List<SaasTransaction> items) {
  final sorted = List<SaasTransaction>.of(items)
    ..sort((a, b) {
      final ka = _dayKey(a);
      final kb = _dayKey(b);
      if (ka == 'no-date' && kb == 'no-date') {
        return (b.createdAt ?? '').compareTo(a.createdAt ?? '');
      }
      if (ka == 'no-date') return 1;
      if (kb == 'no-date') return -1;
      final byDay = kb.compareTo(ka);
      if (byDay != 0) return byDay;
      return (b.createdAt ?? '').compareTo(a.createdAt ?? '');
    });
  final out = <DayBucket>[];
  for (final t in sorted) {
    final k = _dayKey(t);
    if (out.isEmpty || out.last.key != k) {
      out.add(DayBucket(k, [t]));
    } else {
      out.last.items.add(t);
    }
  }
  return out;
}
