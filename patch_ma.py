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
class_match = re.search(r'class MainActivity[^{]*\{', ms)
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
    # Belum ada -> buat baru
    insert_pos = class_match.end()
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
    ms = ms[:insert_pos] + method + ms[insert_pos:]
    print('configureFlutterEngine baru dibuat')

mp.write_text(ms)

# Verifikasi
final = mp.read_text()
assert 'AiFlutterBridge.setup' in final, 'FAIL: Patch gagal!'
assert 'flutterEngine.dartExecutor.binaryMessenger' in final, 'FAIL: binaryMessenger tidak ada!'
assert 'super.configureFlutterEngine' in final, 'FAIL: super call hilang!'
print('MainActivity patch OK')
