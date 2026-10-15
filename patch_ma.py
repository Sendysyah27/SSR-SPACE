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

# 1. Tambah import MethodChannel HANYA jika belum ada (cek semua varian)
has_methodchannel = (
    'import io.flutter.plugin.common.MethodChannel' in ms or
    'import io.flutter.plugin.common.*' in ms
)
if not has_methodchannel:
    import_lines = [l for l in ms.split('\n') if l.strip().startswith('import ')]
    assert import_lines, 'FAIL: Tidak ada baris import di MainActivity!'
    last_import = import_lines[-1]
    ms = ms.replace(
        last_import,
        last_import + '\nimport io.flutter.plugin.common.MethodChannel',
        1
    )
    print('Import MethodChannel ditambahkan')
else:
    print('Import MethodChannel sudah ada, skip')

# Tambah import AiFlutterBridge jika belum ada
ai_import = f'import {ai_pkg}.AiFlutterBridge'
if ai_import not in ms:
    import_lines = [l for l in ms.split('\n') if l.strip().startswith('import ')]
    last_import = import_lines[-1]
    ms = ms.replace(last_import, last_import + '\n' + ai_import, 1)
    print('Import AiFlutterBridge ditambahkan')

# 2. Tambah/kembangkan configureFlutterEngine
class_match = re.search(r'class MainActivity\s*:[^{]*', ms)
assert class_match, 'FAIL: Class MainActivity tidak ketemu!'

if 'override fun configureFlutterEngine' in ms:
    pattern = r'(override fun configureFlutterEngine[^{]*\{[^}]*super\.configureFlutterEngine\([^)]*\))'
    sm = re.search(pattern, ms)
    assert sm, 'FAIL: configureFlutterEngine ada tapi tidak panggil super!'
    inject = sm.group(1) + '\n        AiFlutterBridge.setup(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AiFlutterBridge.CHANNEL))'
    ms = ms[:sm.start()] + inject + ms[sm.end():]
    print('Inject ke configureFlutterEngine yang ada')
else:
    class_decl_end = class_match.end()
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
        brace_pos = ms.find('{', class_decl_end)
        ms = ms[:brace_pos+1] + method + ms[brace_pos+1:]
        print('configureFlutterEngine ditambahkan ke class body yang ada')
    else:
        ms = ms[:class_decl_end] + ' {' + method + '\n}' + ms[class_decl_end:]
        print('configureFlutterEngine baru dibuat dengan class body')

mp.write_text(ms)

# Verifikasi
final = mp.read_text()
assert 'AiFlutterBridge.setup' in final, 'FAIL: Patch gagal!'
assert 'flutterEngine.dartExecutor.binaryMessenger' in final, 'FAIL: binaryMessenger tidak ada!'
assert 'super.configureFlutterEngine' in final, 'FAIL: super call hilang!'
# Pastikan tidak ada duplikat import
mc_count = final.count('import io.flutter.plugin.common.MethodChannel')
assert mc_count <= 1, f'FAIL: Duplikat import MethodChannel ({mc_count}x)!'
print('MainActivity patch OK')
