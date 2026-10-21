// PiiMasker (batch 281D tahap 4, pola Ollo): masking nomor sensitif
// di SISI KLIEN sebelum teks dikirim ke Edge Function. Menjaga
// false-positive nominal: angka transaksi (termasuk format titik
// ribuan & nominal miliaran 10-12 digit tanpa konteks kartu/rekening)
// TIDAK dimasking — yang dimasking hanya pola kartu/rekening/telepon
// yang jelas.

String _last4(String digits) =>
    digits.length <= 4 ? digits : digits.substring(digits.length - 4);

/// Masking PII atas [input]. MURNI. Urutan aturan:
/// 1. Angka 10-12 digit yang didahului kata konteks kartu/rekening
///    (rek/rekening/norek/kartu/atm/cc) -> **** + 4 digit terakhir.
/// 2. Rangkaian 13+ digit dengan pemisah spasi/strip (pola kartu)
///    -> **** + 4 digit terakhir.
/// 3. Rangkaian digit polos 13+ (kartu/rekening panjang)
///    -> **** + 4 digit terakhir.
/// 4. Nomor HP Indonesia (08... / +628..., 10-14 digit total)
///    -> 4 digit awal + **** + 3 digit akhir.
String maskPii(String input) {
  var out = input;
  out = out.replaceAllMapped(
    RegExp(r'\b(rek|rekening|norek|kartu|atm|cc)\b(\s*[:.]?\s*)\d{10,12}(?!\d)',
        caseSensitive: false),
    (m) {
      final digits = m[0]!.replaceAll(RegExp(r'\D'), '');
      return '${m[1]}${m[2]}****${_last4(digits)}';
    },
  );
  out = out.replaceAllMapped(
    RegExp(r'(?<!\d)(?:\d[ -]?){12,}\d(?!\d)'),
    (m) {
      final digits = m[0]!.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 13) return m[0]!;
      return '****${_last4(digits)}';
    },
  );
  out = out.replaceAllMapped(
    RegExp(r'(?<!\d)\d{13,}(?!\d)'),
    (m) => '****${_last4(m[0]!)}',
  );
  out = out.replaceAllMapped(
    RegExp(r'(?<!\d)(?:\+?62|0)8\d{7,11}(?!\d)'),
    (m) {
      final d = m[0]!.replaceAll(RegExp(r'\D'), '');
      if (d.length <= 7) return m[0]!;
      return '${d.substring(0, 4)}****${d.substring(d.length - 3)}';
    },
  );
  return out;
}
