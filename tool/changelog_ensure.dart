// tool/changelog_ensure.dart
//
// Pastikan assets/changelog_id.md selaras dengan versi pubspec saat ini:
//  1. baris "Versi terpasang: <v>." diselaraskan,
//  2. seksi "## Yang baru di <v>" (+ EN) ada; bila belum, sisipkan stub.
//
// Jalankan: dart tool/changelog_ensure.dart   (dari root repo, tanpa flutter)
// WAJIB dijalankan pada setiap commit bump versi - CI men-skip **.md
// (paths-ignore di apk.yml), jadi changelog tak bisa diupdate via CI.
import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final m = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
  if (m == null) {
    stderr.writeln('versi tak ketemu di pubspec.yaml');
    exit(1);
  }
  final ver = m.group(1)!;
  final f = File('assets/changelog_id.md');
  var text = f.readAsStringSync();
  var changed = false;

  // 1. Selaraskan "Versi terpasang".
  // \S+ menelan versi+titik akhir sekaligus (versi mengandung titik).
  final verLine = RegExp(r'Versi terpasang: \S+');
  if (verLine.hasMatch(text)) {
    final updated = text.replaceFirst(verLine, 'Versi terpasang: $ver.');
    if (updated != text) {
      text = updated;
      changed = true;
      stdout.writeln('versi terpasang -> $ver');
    }
  }

  // 2. Pastikan seksi versi ada; bila belum, sisipkan stub untuk diisi manual.
  if (!text.contains('## Yang baru di $ver')) {
    final stub = """
## Yang baru di $ver

1. (isi perubahan versi ini - WAJIB diisi sebelum rilis)

## What's new in $ver

1. (describe this version changes)

""";
    final anchor = RegExp(r'^## ', multiLine: true).firstMatch(text);
    if (anchor != null) {
      text = text.substring(0, anchor.start) + stub + text.substring(anchor.start);
    } else {
      text = '$text\n$stub';
    }
    changed = true;
    stdout.writeln('STUB seksi $ver disisipkan - ISI MANUAL sebelum rilis.');
  }

  if (changed) {
    f.writeAsStringSync(text);
    stdout.writeln('changelog_id.md diperbarui.');
  } else {
    stdout.writeln('changelog sudah selaras dengan $ver.');
  }
}
