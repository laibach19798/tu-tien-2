"""Phân tích kết quả build_sim: mỗi ô giải thích bao nhiêu phương sai, cặp nào phối hợp thật.
Chạy: python tools/build_sim_analyze.py [base|rolled]"""
import collections
import csv
import statistics as st
import sys

name = sys.argv[1] if len(sys.argv) > 1 else 'base'
all_rows = list(csv.DictReader(open('tools/build_sim_%s.csv' % name, encoding='utf-8')))
for r in all_rows:
    r['o'] = float(r['overall'])
rows = [r for r in all_rows if r['cong']]
gm = st.mean(r['o'] for r in rows)
tot = st.pvariance([r['o'] for r in rows])


def share(key, getter=None):
    g = collections.defaultdict(list)
    for r in rows:
        g[getter(r) if getter else r[key]].append(r['o'])
    return 100 * sum(len(v) * (st.mean(v) - gm) ** 2 for v in g.values()) / len(rows) / tot, {k: st.mean(v) for k, v in g.items()}


print('== %s: %d tổ hợp có Công Pháp ==' % (name, len(rows)))
means = {}
for k in ['cong', 'tam', 'than', 'artifact']:
    s, m = share(k)
    means[k] = m
    print('%-9s giải thích %.1f%% phương sai' % (k, s))
s_ct, _ = share('x', lambda r: (r['cong'], r['tam']))
s_cth, _ = share('x', lambda r: (r['cong'], r['tam'], r['than']))
print('cặp Công+Tâm giải thích %.1f%% | cả bộ Công+Tâm+Thân giải thích %.1f%%' % (s_ct, s_cth))
vals = sorted(r['o'] for r in rows)
print('min %.2f | p10 %.2f | p50 %.2f | p90 %.2f | max %.2f | <0.5: %.1f%%' % (
    vals[0], vals[len(vals) // 10], vals[len(vals) // 2], vals[9 * len(vals) // 10], vals[-1],
    100 * sum(v < 0.5 for v in vals) / len(vals)))
for k in ['cong', 'tam', 'than']:
    print(k, ' '.join('%s=%.2f' % (a, b) for a, b in sorted(means[k].items(), key=lambda x: -x[1])))
# tương tác Công x Tâm so với kỳ vọng nhân
g = collections.defaultdict(list)
for r in rows:
    g[(r['cong'], r['tam'])].append(r['o'])
ratios = []
for (c, t), v in g.items():
    ratios.append((st.mean(v) / (means['cong'][c] * means['tam'][t] / gm), c, t, st.mean(v)))
ratios.sort()
rs = [x[0] for x in ratios]
print('hệ số phối hợp Công x Tâm: p5 %.2f | p50 %.2f | p95 %.2f | min %.2f | max %.2f' % (
    rs[len(rs) // 20], rs[len(rs) // 2], rs[-len(rs) // 20], rs[0], rs[-1]))
print('mạnh nhất:', ', '.join('%.2f %s+%s' % x[:3] for x in ratios[::-1][:6]))
print('kém nhất :', ', '.join('%.2f %s+%s' % x[:3] for x in ratios[:6]))
# Thân x Công
g = collections.defaultdict(list)
for r in rows:
    g[(r['cong'], r['than'])].append(r['o'])
rt = sorted((st.mean(v) / (means['cong'][c] * means['than'][t] / gm), c, t) for (c, t), v in g.items())
print('Công x Thân: min %.2f | max %.2f' % (rt[0][0], rt[-1][0]))
