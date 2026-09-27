/// Varian copy pengingat harian (P2 reminder-copy), Dart murni.
///
/// Rotasi deterministik per tanggal (bukan acak) agar QA bisa memprediksi:
/// indeks = (tahun*372 + bulan*31 + hari) % jumlah varian.
/// Konteks: 3 hari terakhir bulan pakai varian akhir-bulan, selebihnya
/// pagi (jam < 15) atau malam. Tanpa nominal user agar aman di lockscreen.
const morningCopyKeys = <String>[
  'rmc_m1',
  'rmc_m2',
  'rmc_m3',
  'rmc_m4',
  'rmc_m5',
  'rmc_m6',
];

const eveningCopyKeys = <String>[
  'rmc_e1',
  'rmc_e2',
  'rmc_e3',
  'rmc_e4',
  'rmc_e5',
  'rmc_e6',
];

const monthEndCopyKeys = <String>[
  'rmc_b1',
  'rmc_b2',
];

/// True bila [date] masuk 3 hari terakhir bulan kalender.
bool isMonthEnd(DateTime date) {
  final lastDay = DateTime(date.year, date.month + 1, 0).day;
  return date.day >= lastDay - 2;
}

int _stableDay(DateTime date) => date.year * 372 + date.month * 31 + date.day;

/// Kunci strings untuk pengingat pada [date] dan jam terjadwal [hour].
String reminderKeyFor(DateTime date, int hour) {
  if (isMonthEnd(date)) {
    return monthEndCopyKeys[_stableDay(date) % monthEndCopyKeys.length];
  }
  final list = hour < 15 ? morningCopyKeys : eveningCopyKeys;
  return list[_stableDay(date) % list.length];
}
