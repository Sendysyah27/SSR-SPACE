#!/usr/bin/env bash
# Gate P1-5 (audit 2026-11-25): cegah TAMBAHAN catch senyap.
# `catch (_) {}` telanjang dilarang (AGENTS.md §7 aturan 10) kecuali
# disertai komentar `// best-effort:` + debugPrint. Baseline mencatat
# jumlah pola same-line kosong yang belum dibersihkan; gate gagal bila
# bertambah. Turunkan baseline tiap kali membersihkan.
set -euo pipefail
cd "$(dirname "$0")/.."
BASE="$(cat tool/silent_catch_baseline.txt 2>/dev/null || echo 0)"
CUR="$(grep -rInE 'catch\s*(\([^)]*\))?\s*\{\s*\}' lib --include='*.dart' \
  | grep -v 'best-effort' | wc -l | tr -d ' ')"
echo "catch senyap (same-line kosong): $CUR (baseline $BASE)"
if [ "$CUR" -gt "$BASE" ]; then
  echo "GAGAL: catch senyap bertambah. Bungkus dgn '// best-effort:' + debugPrint," >&2
  echo "atau turunkan baseline bila ini pembersihan yang disengaja." >&2
  grep -rInE 'catch\s*(\([^)]*\))?\s*\{\s*\}' lib --include='*.dart' \
    | grep -v 'best-effort' >&2 || true
  exit 1
fi
echo "OK"
