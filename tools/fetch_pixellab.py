"""Tải tài nguyên Pixellab về dự án. Dùng: python tools/fetch_pixellab.py tiles <prefix> <tiles_id> | obj <tên> <object_id>
tiles: 16 ảnh -> assets/ground/<prefix>_<base|alt|path|rock>_<0..3>.png (hàng 0 base, 1 alt, 2 path, 3 rock)."""
import sys, urllib.request, os
USER = 'a7636ebc-af31-4668-b7d3-6304b1937399'
ROWS = ['base', 'alt', 'path', 'rock']
def get(url, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=60) as r, open(dest, 'wb') as f:
        f.write(r.read())
if sys.argv[1] == 'tiles':
    prefix, tid = sys.argv[2], sys.argv[3]
    for i in range(16):
        get('https://backblaze.pixellab.ai/file/pixellab-tiles/%s/%s/tile_%d.png' % (USER, tid, i),
            'assets/ground/%s_%s_%d.png' % (prefix, ROWS[i // 4], i % 4))
    print('tiles ok', prefix)
else:
    name, oid = sys.argv[2], sys.argv[3]
    get('https://api.pixellab.ai/mcp/map-objects/%s/download' % oid, 'assets/props/%s.png' % name)
    print('obj ok', name)
