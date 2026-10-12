// Filter + favorit pencarian Transaksi (Batch 28).
// Murni Dart: tanpa Flutter/Supabase. Favorit disimpan prefs
// `tx_filter_favs` (stringList JSON, cap-10, terbaru dulu).
import 'dart:convert';

import '../models/transaction.dart';

// Kunci prefs + batas favorit.
const kTxFavKey = 'tx_filter_favs';
const kTxFavCap = 10;

// Kriteria saring. Set kosong = semua lolos untuk dimensi itu.
class TxFilter {
  final String query;
  final Set<String> types;
  final Set<String> cats;
  final String? dateFrom;
  final String? dateTo;
  final double? minAmount;
  final double? maxAmount;

  const TxFilter({
    this.query = '',
    this.types = const {},
    this.cats = const {},
    this.dateFrom,
    this.dateTo,
    this.minAmount,
    this.maxAmount,
  });

  bool get isEmpty =>
      query.trim().isEmpty &&
      types.isEmpty &&
      cats.isEmpty &&
      dateFrom == null &&
      dateTo == null &&
      minAmount == null &&
      maxAmount == null;

  Map<String, dynamic> toMap() => {
        'q': query,
        't': types.toList(),
        'c': cats.toList(),
        'df': dateFrom,
        'dt': dateTo,
        'min': minAmount,
        'max': maxAmount,
      };

  factory TxFilter.fromMap(Map<String, dynamic> m) {
    Set<String> strSet(dynamic v) => {
          for (final e in (v as List? ?? [])) e.toString(),
        };
    double? numOrNull(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    String? ymdOrNull(dynamic v) {
      final s = '${v ?? ''}';
      return s.length >= 10 ? s.substring(0, 10) : null;
    }

    return TxFilter(
      query: '${m['q'] ?? ''}',
      types: strSet(m['t']),
      cats: strSet(m['c']),
      dateFrom: ymdOrNull(m['df']),
      dateTo: ymdOrNull(m['dt']),
      minAmount: numOrNull(m['min']),
      maxAmount: numOrNull(m['max']),
    );
  }
}

// Satu filter favorit bernama.
class TxFav {
  final String name;
  final TxFilter filter;
  const TxFav({required this.name, required this.filter});

  Map<String, dynamic> toMap() => {'n': name, 'f': filter.toMap()};

  factory TxFav.fromMap(Map<String, dynamic> m) => TxFav(
        name: '${m['n'] ?? ''}',
        filter: TxFilter.fromMap(
          Map<String, dynamic>.from((m['f'] as Map?) ?? {}),
        ),
      );
}

// True bila satu transaksi lolos filter.
bool matchesTx(SaasTransaction t, TxFilter f) {
  final q = f.query.trim().toLowerCase();
  if (q.isNotEmpty) {
    final hay = [
      t.category ?? '',
      t.note ?? '',
      t.code ?? '',
    ].join(' ').toLowerCase();
    if (!hay.contains(q)) return false;
  }
  if (f.types.isNotEmpty && !f.types.contains(t.type)) return false;
  if (f.cats.isNotEmpty && !f.cats.contains(t.category ?? '')) return false;
  if (f.dateFrom != null || f.dateTo != null) {
    final d = (t.date ?? '');
    final day = d.length >= 10 ? d.substring(0, 10) : '';
    if (day.isEmpty) return false;
    if (f.dateFrom != null && day.compareTo(f.dateFrom!) < 0) return false;
    if (f.dateTo != null && day.compareTo(f.dateTo!) > 0) return false;
  }
  if (f.minAmount != null && t.amount < f.minAmount!) return false;
  if (f.maxAmount != null && t.amount > f.maxAmount!) return false;
  return true;
}

// Saring list tanpa memutasi input. Filter kosong = salinan utuh.
List<SaasTransaction> applyTxFilter(
  List<SaasTransaction> items,
  TxFilter f,
) {
  if (f.isEmpty) return List<SaasTransaction>.of(items);
  return [for (final t in items) if (matchesTx(t, f)) t];
}

// Tambah favorit di depan, potong ekor di cap. Murni, tanpa IO.
List<TxFav> addTxFav(List<TxFav> cur, TxFav fav) {
  final next = [fav, ...cur];
  return next.length > kTxFavCap
      ? next.sublist(0, kTxFavCap)
      : next;
}

// Encode/decode stringList prefs (rusak = dilewati, bukan error).
List<String> encodeTxFavs(List<TxFav> favs) =>
    [for (final f in favs) jsonEncode(f.toMap())];

List<TxFav> decodeTxFavs(List<String> raw) {
  final out = <TxFav>[];
  for (final s in raw) {
    try {
      out.add(TxFav.fromMap(
        Map<String, dynamic>.from(jsonDecode(s) as Map),
      ));
    } catch (_) {
      // Entri rusak dilewati.
    }
  }
  return out;
}
