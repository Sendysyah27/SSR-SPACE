// qris.test.ts — Unit test generator QRIS (node:test, tanpa Deno karena
// binary Deno glibc tidak jalan di Termux/Android; test ini murni logika).
// Semua vektor & output ekspektasi dihasilkan oleh referensi Python
// `qris_dynamic.py` (implementasi yang terbukti dibayar E2E 2026-10-20),
// BUKAN ditebak. Sampel payload di bawah ANONIM (merchant fiktif
// "TOKO CONTOH") — payload merchant asli TIDAK PERNAH masuk repo.

import { test } from "node:test";
import assert from "node:assert/strict";

import { crc16_ccitt, make_dynamic, parse_tlv } from "./qris.ts";

// Payload statis anonim, struktur EMVCo/QRIS valid, CRC (D278) benar.
const STATIC_SAMPLE =
  "00020101021126590014ID.CO.QRIS.WWW01189360091400000000000308CONTOH010403UMI5204541153033605802ID5911TOKO CONTOH6007JAKARTA6105101106304D278";

// Output make_dynamic(STATIC_SAMPLE, 30137) menurut referensi Python —
// harus identik bit-per-bit.
const EXPECTED_DYNAMIC_30137 =
  "00020101021226590014ID.CO.QRIS.WWW01189360091400000000000308CONTOH010403UMI5204541153033605405301375802ID5911TOKO CONTOH6007JAKARTA61051011063042521";

test("crc16_ccitt '123456789' = 29B1 (check value standar CCITT-FALSE)", () => {
  assert.equal(crc16_ccitt("123456789"), "29B1");
});

test("crc16_ccitt string kosong = FFFF (nilai init)", () => {
  assert.equal(crc16_ccitt(""), "FFFF");
});

test("crc16_ccitt '0' = D7A3 (vektor referensi Python)", () => {
  assert.equal(crc16_ccitt("0"), "D7A3");
});

test("parse_tlv memparse TLV sederhana", () => {
  assert.deepEqual(parse_tlv("000201010211"), [
    ["00", "01"],
    ["01", "11"],
  ]);
});

test("parse_tlv payload statis sampel utuh + CRC statis valid", () => {
  const tags = parse_tlv(STATIC_SAMPLE);
  const map = new Map(tags);
  assert.equal(map.get("01"), "11"); // statis
  assert.equal(map.get("53"), "360"); // IDR
  assert.equal(map.get("59"), "TOKO CONTOH");
  assert.equal(tags[tags.length - 1][0], "63");
  assert.equal(crc16_ccitt(STATIC_SAMPLE.slice(0, -4)), map.get("63"));
});

test("make_dynamic identik bit-per-bit dengan referensi Python (30137)", () => {
  assert.equal(make_dynamic(STATIC_SAMPLE, 30137), EXPECTED_DYNAMIC_30137);
});

test("make_dynamic: tag01->12, tag54 sesudah tag53, CRC dinamis valid", () => {
  const dyn = make_dynamic(STATIC_SAMPLE, 45500);
  const tags = parse_tlv(dyn);
  const map = new Map(tags);
  assert.equal(map.get("01"), "12"); // dinamis
  assert.equal(map.get("54"), "45500");
  const idx53 = tags.findIndex(([t]) => t === "53");
  assert.equal(tags[idx53 + 1][0], "54"); // tepat setelah tag 53
  assert.equal(crc16_ccitt(dyn.slice(0, -4)), dyn.slice(-4)); // CRC valid
});

test("make_dynamic menolak payload dengan CRC statis rusak", () => {
  const rusak = STATIC_SAMPLE.slice(0, -1) + "0"; // CRC asli berakhiran 8
  assert.throws(() => make_dynamic(rusak, 1000), /CRC payload statis tidak valid/);
});
