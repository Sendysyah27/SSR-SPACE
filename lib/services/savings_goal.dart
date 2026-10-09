/// Target nabung (Goals). Dart murni, offline-first.
///
/// Satu goal: nama + target + deadline opsional + ikon (nama kategori
/// yang badge-nya dipakai ulang, default Tabungan) + mode setor manual
/// atau auto-ikut kategori. Nominal tersimpan = setor manual; porsi
/// auto dihitung pemanggil dari transaksi (tak disimpan di sini).
const maxGoals = 20;

class SavingsGoal {
  final String id;
  final String name;
  final double target;
  final double savedManual;
  final String? deadline;
  final String icon;
  final bool auto;
  final String linkCategory;

  /// Awal akrual auto (YYYY-MM-DD). Diisi saat goal dibuat.
  final String since;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    this.savedManual = 0,
    this.deadline,
    this.icon = 'Tabungan',
    this.auto = true,
    this.linkCategory = 'Tabungan',
    this.since = '',
  });

  /// Progres 0..1. [autoSaved] = terkumpul dari kategori (diabaikan bila
  /// mode manual). Lebih dari target = 1 (tampil 100%+ via [overBy]).
  double progress(double autoSaved) {
    if (target <= 0) return 0;
    final got = savedManual + (auto ? autoSaved : 0);
    final p = got / target;
    return p > 1 ? 1 : (p < 0 ? 0 : p);
  }

  /// Sisa nominal (negatif bila lewat target).
  double remaining(double autoSaved) =>
      target - savedManual - (auto ? autoSaved : 0);

  /// Sisa hari ke deadline (null tanpa deadline). Negatif = lewat.
  int? daysLeft(DateTime today) {
    if (deadline == null) return null;
    final dl = DateTime.tryParse(deadline!);
    if (dl == null) return null;
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(dl.year, dl.month, dl.day);
    return b.difference(a).inDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'savedManual': savedManual,
        'deadline': deadline,
        'icon': icon,
        'auto': auto,
        'linkCategory': linkCategory,
        'since': since,
      };

  /// Parse toleran: null bila bentuk tak dikenal (entri rusak dibuang).
  static SavingsGoal? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    final name = (raw['name']?.toString() ?? '').trim();
    final target = (raw['target'] as num?)?.toDouble();
    if (id.isEmpty || name.isEmpty || target == null || target <= 0) {
      return null;
    }
    final saved = (raw['savedManual'] as num?)?.toDouble() ?? 0;
    String? dl;
    final rawDl = raw['deadline']?.toString();
    if (rawDl != null && rawDl.isNotEmpty) {
      if (DateTime.tryParse(rawDl) == null) return null;
      dl = rawDl.substring(0, 10);
    }
    final icon = (raw['icon']?.toString() ?? '').trim();
    final since = (raw['since']?.toString() ?? '').trim();
    return SavingsGoal(
      id: id,
      name: name.length > 40 ? name.substring(0, 40) : name,
      target: target,
      savedManual: saved < 0 ? 0 : saved,
      deadline: dl,
      icon: icon.isEmpty ? 'Tabungan' : icon,
      auto: raw['auto'] != false,
      linkCategory:
          (raw['linkCategory']?.toString() ?? '').trim().isEmpty
              ? 'Tabungan'
              : (raw['linkCategory'] as String).trim(),
      since: since.length >= 10 ? since.substring(0, 10) : '',
    );
  }
}
