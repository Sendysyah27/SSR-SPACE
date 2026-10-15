#!/usr/bin/env python3
"""Patch MainActivity.kt untuk daftarkan AiFlutterBridge.
IDEMPOTENT: skip jika sudah ada.
FAIL KERAS jika pola tidak ketemu.
"""
import glob
import pathlib
import re
import sys

mains = glob.glob('android/app/src/main/kotlin/**/MainActivity.*', recursive=True)
mains += glob.glob('android/app/src/main/java/**/MainActivity.*', recursive=True)
assert len(mains) == 1, f'MainActivity tak ketemu: {mains}'

mp = pathlib.Path(mains[0])
ms = mp.read_text()

if 'AiFlutterBridge.setup' in ms:
    print('MainActivity sudah ada AiFlutterBridge.setup, skip (idempotent)')
    sys.exit(0)

# Tentukan package
parts = mp.parent.parts
idx = parts.index('kotlin' if 'kotlin' in parts else 'java')
pkg = '.'.join(parts[idx+1:])
ai_pkg = pkg + '.ai'

# 1. Tambah import (FAIL KERAS jika tidak ada import)
if 'import io.flutter.plugin.common.MethodChannel' not in ms:
    import_lines = [l for l in ms.split('\n') if l.strip().startswith('import ')]
    assert import_lines, 'FAIL: Tidak ada baris import di MainActivity!'
    last_import = import_lines[-1]
    ms = ms.replace(
        last_import,
        last_import + '\nimport io.flutter.plugin.common.MethodChannel\nimport ' + ai_pkg + '.AiFlutterBridge',
        1
    )
    print('Import ditambahkan')

# 2. Tambah/kembangkan configureFlutterEngine
# Cari class MainActivity - bisa dengan atau tanpa body { }
# Format 1: class MainActivity: FlutterActivity() { ... }
# Format 2: class MainActivity: FlutterActivity()  (tanpa body)
class_match = re.search(r'class MainActivity\s*:[^{]*', ms)
assert class_match, 'FAIL: Class MainActivity tidak ketemu!'

if 'override fun configureFlutterEngine' in ms:
    # Sudah ada -> inject setelah super.configureFlutterEngine(...)
    pattern = r'(override fun configureFlutterEngine[^{]*\{[^}]*super\.configureFlutterEngine\([^)]*\))'
    sm = re.search(pattern, ms)
    assert sm, 'FAIL: configureFlutterEngine ada tapi tidak panggil super!'
    inject = sm.group(1) + '\n        AiFlutterBridge.setup(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AiFlutterBridge.CHANNEL))'
    ms = ms[:sm.start()] + inject + ms[sm.end():]
    print('Inject ke configureFlutterEngine yang ada')
else:
    # Belum ada -> buat method baru
    # Jika class tanpa body, tambah body dengan method di dalamnya
    # Jika class dengan body, tambah method di dalam body
    class_decl_end = class_match.end()
    # Cek apakah ada { setelah class declaration
    after_class = ms[class_decl_end:class_decl_end+10].strip()
    method = (
        '\n    override fun configureFlutterEngine('
        'flutterEngine: io.flutter.embedding.engine.FlutterEngine'
        ') {\n'
        '        super.configureFlutterEngine(flutterEngine)\n'
        '        AiFlutterBridge.setup(this, MethodChannel('
        'flutterEngine.dartExecutor.binaryMessenger, '
        'AiFlutterBridge.CHANNEL))\n'
        '    }'
    )
    if after_class.startswith('{'):
        # Ada body, insert setelah {
        brace_pos = ms.find('{', class_decl_end)
        ms = ms[:brace_pos+1] + method + ms[brace_pos+1:]
        print('configureFlutterEngine ditambahkan ke class body yang ada')
    else:
        # Tidak ada body, buat body baru
        ms = ms[:class_decl_end] + ' {' + method + '\n}' + ms[class_decl_end:]
        print('configureFlutterEngine baru dibuat dengan class body')

mp.write_text(ms)

# Verifikasi
final = mp.read_text()
assert 'AiFlutterBridge.setup' in final, 'FAIL: Patch gagal!'
assert 'flutterEngine.dartExecutor.binaryMessenger' in final, 'FAIL: binaryMessenger tidak ada!'
assert 'super.configureFlutterEngine' in final, 'FAIL: super call hilang!'
print('MainActivity patch OK')
