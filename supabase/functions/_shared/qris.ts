// qris.ts — Generator payload QRIS dinamis (EMVCo TLV + CRC16-CCITT).
// Port persis dari referensi Python `qris_dynamic.py` yang TERBUKTI
// end-to-end: QR hasil generate berhasil dibayar via iSaku (2026-10-20).
// Dipakai bersama oleh Edge Functions pembayaran QRIS (folder _shared).
//
// Aturan main (sama seperti referensi):
// - Payload statis merchant dibaca dari env QRIS_STATIC_PAYLOAD di Edge
//   Function; file ini TIDAK mengandung payload asli.
// - make_dynamic: tag 01 "11" (statis) -> "12" (dinamis), sisipkan tag 54
//   (nominal) tepat SETELAH tag 53, CRC16 dihitung ulang. Tag lain
//   dipertahankan apa adanya (termasuk tag 62 bila ada).

/** CRC16-CCITT (varian FALSE: poly 0x1021, init 0xFFFF, tanpa refleksi).
 *  Mengembalikan 4 digit hex huruf besar, mis. crc16_ccitt("123456789") = "29B1". */
export function crc16_ccitt(data: string): string {
  let crc = 0xffff;
  for (let i = 0; i < data.length; i++) {
    crc ^= data.charCodeAt(i) << 8;
    for (let b = 0; b < 8; b++) {
      crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, "0");
}

/** Parse payload EMVCo TLV menjadi daftar [tag, value] berurutan. */
export function parse_tlv(s: string): [string, string][] {
  const out: [string, string][] = [];
  let i = 0;
  while (i < s.length) {
    const tag = s.slice(i, i + 2);
    const len = parseInt(s.slice(i + 2, i + 4), 10);
    out.push([tag, s.slice(i + 4, i + 4 + len)]);
    i += 4 + len;
  }
  return out;
}

/** Ubah payload QRIS statis menjadi dinamis dengan nominal tertentu (Rupiah,
 *  integer, SUDAH termasuk kode unik bila ada — penambahan kode unik adalah
 *  tanggung jawab pemanggil). Melempar Error bila payload statis tidak
 *  diakhiri tag 63 atau CRC statisnya tidak valid. */
export function make_dynamic(staticPayload: string, amount: number): string {
  const tags = parse_tlv(staticPayload);
  const last = tags[tags.length - 1];
  if (!last || last[0] !== "63") {
    throw new Error("payload statis tidak diakhiri tag 63 (CRC)");
  }
  if (crc16_ccitt(staticPayload.slice(0, -4)) !== last[1]) {
    throw new Error("CRC payload statis tidak valid");
  }
  const body: [string, string][] = [];
  for (const [tag, v0] of tags) {
    if (tag === "63") continue;
    body.push([tag, tag === "01" ? "12" : v0]);
    if (tag === "53") body.push(["54", String(amount)]);
  }
  const raw =
    body.map(([t, v]) => t + String(v.length).padStart(2, "0") + v).join("") +
    "6304";
  return raw + crc16_ccitt(raw);
}
