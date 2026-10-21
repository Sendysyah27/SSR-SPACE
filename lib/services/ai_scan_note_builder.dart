import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/services/receipt_scan_parse.dart';

// NoteBuilder catatan scan terstruktur (batch 284 tahap C, pola
// AiScanNoteBuilder + AiScanNoteSettings Ollo): catatan hasil scan
// disusun dari potongan yang URUTANNYA bisa diatur user, plus nama
// pemilik untuk struk transfer. Preferensi di SharedPreferences dengan
// nama kunci sejajar Ollo. Semua IO fail-open: gagal baca -> bawaan
// (fitur menyala, urutan default, tanpa nama pemilik).

/// Kunci potongan catatan yang dikenal builder.
const aiScanNotePieces = ['merchant', 'datetime', 'items', 'total', 'owner'];

/// Urutan bawaan potongan catatan.
const defaultAiScanNoteOrder = [
  'merchant',
  'datetime',
  'items',
  'total',
  'owner',
];

/// Label Bahasa Indonesia per potongan (untuk layar pengaturan).
const aiScanNotePieceLabels = {
  'merchant': 'Nama toko / merchant',
  'datetime': 'Tanggal & jam',
  'items': 'Ringkasan item',
  'total': 'Total',
  'owner': 'Nama pemilik',
};

const _kNoteEnabled = 'ai_scan_note_enabled';
const _kNoteOrder = 'ai_scan_note_order';
const _kOwnerName = 'ai_scan_owner_name';

/// Preferensi catatan scan.
class AiScanNoteSettings {
  final bool enabled;
  final List<String> order;
  final String ownerName;

  const AiScanNoteSettings({
    this.enabled = true,
    this.order = defaultAiScanNoteOrder,
    this.ownerName = '',
  });

  AiScanNoteSettings copyWith({
    bool? enabled,
    List<String>? order,
    String? ownerName,
  }) {
    return AiScanNoteSettings(
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      ownerName: ownerName ?? this.ownerName,
    );
  }
}

/// MURNI: bersihkan urutan mentah — hanya potongan dikenal, dedupe,
/// potongan yang hilang ditambahkan di akhir (fitur baru tetap muncul).
/// Kosong / tak valid -> urutan bawaan.
List<String> sanitizeAiScanNoteOrder(List<String>? raw) {
  if (raw == null) return [...defaultAiScanNoteOrder];
  final out = <String>[];
  for (final k in raw) {
    final t = k.trim();
    if (aiScanNotePieces.contains(t) && !out.contains(t)) out.add(t);
  }
  for (final k in defaultAiScanNoteOrder) {
    if (!out.contains(k)) out.add(k);
  }
  return out;
}

/// Muat preferensi catatan scan (fail-open ke bawaan).
Future<AiScanNoteSettings> loadAiScanNoteSettings() async {
  try {
    final p = await SharedPreferences.getInstance();
    return AiScanNoteSettings(
      enabled: p.getBool(_kNoteEnabled) ?? true,
      order: sanitizeAiScanNoteOrder(p.getStringList(_kNoteOrder)),
      ownerName: p.getString(_kOwnerName) ?? '',
    );
  } catch (_) {
    return const AiScanNoteSettings();
  }
}

/// Simpan preferensi catatan scan (fail-silent).
Future<void> saveAiScanNoteSettings(AiScanNoteSettings s) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNoteEnabled, s.enabled);
    await p.setStringList(_kNoteOrder, sanitizeAiScanNoteOrder(s.order));
    await p.setString(_kOwnerName, s.ownerName.trim());
  } catch (_) {}
}

/// MURNI: susun catatan dari potongan sesuai [order]. Potongan yang
/// datanya kosong dilewati. Potongan pemilik hanya tampil bila
/// [ownerName] terisi DAN namanya benar-benar muncul di [sourceText]
/// (teks struk, tak sensitif huruf) — pola nama pemilik Ollo.
String buildAiScanNote({
  required List<String> order,
  String? merchant,
  String? dateTimeText,
  String? itemsText,
  String? totalText,
  String? ownerName,
  String? sourceText,
}) {
  String? piece(String key) {
    switch (key) {
      case 'merchant':
        final v = (merchant ?? '').trim();
        return v.isEmpty ? null : v;
      case 'datetime':
        final v = (dateTimeText ?? '').trim();
        return v.isEmpty ? null : v;
      case 'items':
        final v = (itemsText ?? '').trim();
        return v.isEmpty ? null : v;
      case 'total':
        final v = (totalText ?? '').trim();
        return v.isEmpty ? null : v;
      case 'owner':
        final name = (ownerName ?? '').trim();
        if (name.isEmpty) return null;
        final src = (sourceText ?? '').toLowerCase();
        if (!src.contains(name.toLowerCase())) return null;
        return 'Pemilik: $name';
    }
    return null;
  }

  final lines = <String>[];
  String? firstKey;
  for (final key in sanitizeAiScanNoteOrder(order)) {
    final v = piece(key);
    if (v != null) {
      firstKey ??= key;
      lines.add(v);
    }
  }
  // Penanda struk dipertahankan bila merchant potongan pertama
  // (render gaya struk di daftar/detail transaksi tetap jalan).
  if (firstKey == 'merchant' && lines.isNotEmpty) {
    lines[0] = '$receiptNoteMarker ${lines[0]}';
  }
  return lines.join('\n');
}

String _groupIdr(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Bangun catatan scan dari [data] + preferensi tersimpan.
/// - Fitur mati -> '' (catatan hasil scan DIKOSONGKAN — kriteria
///   terima brief 284; pemanggil wajib membedakan '' vs null).
/// - Error tak terduga -> null (pemanggil jatuh ke perilaku lama).
/// [sourceText]: teks bahan pencocokan nama pemilik (OCR mentah / detail).
Future<String?> buildScanNoteFor(ReceiptData data,
    {String? sourceText}) async {
  try {
    final st = await loadAiScanNoteSettings();
    if (!st.enabled) return '';
    String? dateTimeText;
    if (data.date != null) {
      final t = (data.time ?? '').trim();
      dateTimeText = t.isEmpty ? _ymd(data.date!) : '${_ymd(data.date!)} $t';
    }
    String? itemsText;
    if (data.lineItems.isNotEmpty) {
      final buf = StringBuffer();
      var n = 0;
      for (final li in data.lineItems) {
        n++;
        final qty = li.qty > 1 ? ' x${li.qty}' : '';
        buf.writeln('$n. ${li.name}$qty — Rp ${_groupIdr(li.price.round())}');
      }
      itemsText = buf.toString().trimRight();
    } else if (data.items.isNotEmpty) {
      itemsText = data.items.join(', ');
    }
    final totalText = (data.amount != null && data.amount! > 0)
        ? 'TOTAL Rp ${_groupIdr(data.amount!.round())}'
        : null;
    final src = sourceText ??
        [data.merchant ?? '', data.detailText ?? '', data.items.join(' ')]
            .join('\n');
    return buildAiScanNote(
      order: st.order,
      merchant: data.merchant,
      dateTimeText: dateTimeText,
      itemsText: itemsText,
      totalText: totalText,
      ownerName: st.ownerName,
      sourceText: src,
    );
  } catch (_) {
    return null;
  }
}
