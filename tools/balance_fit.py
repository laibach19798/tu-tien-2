"""Lặp: đo từng Công Pháp/pháp bảo chủ lực (build_sim.gd -- fit) rồi chỉnh sát thương cho đều.
Chạy: python tools/balance_fit.py [số vòng]"""
import json
import subprocess
import sys

import os
GODOT = os.path.abspath('tools/Godot-4.7.2-stable-win64/app/Godot_v4.7.2-stable_win64_console.exe')


def measure():
    out = subprocess.run([GODOT, '--headless', '--path', '.', '--script', 'res://tools/build_sim.gd', '--', 'fit'],
                         capture_output=True, text=True, encoding='utf-8', errors='replace').stdout
    for line in out.splitlines():
        if line.startswith('FITJSON '):
            return json.loads(line[8:])
    raise SystemExit('không đọc được kết quả:\n' + out[-800:])


rounds = int(sys.argv[1]) if len(sys.argv) > 1 else 4
for i in range(rounds):
    res = measure()
    ov = res['overall']
    spread = max(ov.values()) / max(0.01, min(ov.values()))
    print('vòng %d: chênh lệch max/min = %.2f' % (i, spread))
    print('  ' + ' '.join('%s=%.2f' % (k, v) for k, v in sorted(ov.items(), key=lambda x: -x[1])))
    mult = {k: max(0.5, min(2.0, (1.0 / max(0.05, v)) ** 0.75)) for k, v in ov.items()}
    subprocess.run([sys.executable, 'tools/balance_v1.py', 'fit-apply', json.dumps(mult)], check=True)
res = measure()
ov = res['overall']
print('cuối: chênh lệch max/min = %.2f' % (max(ov.values()) / max(0.01, min(ov.values()))))
print('  ' + ' '.join('%s=%.2f' % (k, v) for k, v in sorted(ov.items(), key=lambda x: -x[1])))
