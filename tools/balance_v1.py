"""Bảng số V1.3 (cân bằng theo mô phỏng). Chạy: python tools/balance_v1.py base | fit-apply <json>
Sau đó chạy tools/build_sim.gd để đo lại (xem tools/CULTIVATION_V1.md)."""
import json
import sys

P = 'data/cultivation_v1.json'


def load():
    return json.load(open(P, encoding='utf-8'))


def save(d):
    out = json.dumps(d, ensure_ascii=False, indent=2)
    open(P, 'w', encoding='utf-8', newline='').write(out.replace('\n', '\r\n'))


def apply_base():
    d = load()
    # Độ khó địa ngục (V1.5): linh lực hồi chậm hơn, sách/tham ngộ/công huân đắt hơn, tàn quyển hiếm hơn
    d['balance'].update({'qi_regen': 1.0, 'book_price': 1500, 'gear_price': 2200, 'study_stones': 500, 'study_seconds': 120, 'sect_merit': 240, 'ruin_kills': 14})
    st = d['statuses']
    for k, f in {'kiem_an': 'mark', 'hon_an': 'mark', 'bleed': 'dot', 'burn': 'dot', 'slow': 'control',
                 'armor_break': 'debuff', 'weaken': 'debuff'}.items():
        st[k]['family'] = f
    st['surge'] = {"name": "Thừa Thế", "max_stacks": 1, "duration": 4, "harmful": False, "refresh": "reset",
                   "damage_bonus": 0.4, "family": "buff"}
    bk = {x['id']: x for x in d['books']}
    cong = {  # chi phí, hồi chiêu, sát thương gốc (sát thương sẽ được fit lại)
        'kiem_cut': (12, 0.55, 22), 'kiem_wave': (70, 3, 120), 'dao_cut': (16, 0.8, 30), 'dao_break': (50, 2.5, 90),
        'ngu_fire': (40, 1.8, 70), 'ngu_water': (35, 1.6, 45), 'the_fist': (14, 0.7, 30), 'the_quake': (55, 3, 100),
        'hon_seal': (30, 1.1, 45), 'hon_clone': (55, 8, 32)}
    for k, (c, cd, dm) in cong.items():
        bk[k]['cost'] = c
        bk[k]['cooldown'] = cd
        bk[k]['damage'] = dm
    bk['hon_clone']['duration'] = 6
    for k, ct in {'kiem_wave': 0.2, 'dao_break': 0.2, 'ngu_fire': 0.2, 'the_quake': 0.25, 'hon_clone': 0.2}.items():
        bk[k]['cast_time'] = ct
    for k, c in {'kiem_step': 16, 'kiem_guard': 30, 'dao_chase': 24, 'dao_retreat': 20, 'ngu_earth': 34,
                 'ngu_waterstep': 22, 'the_step': 16, 'the_leap': 38, 'hon_step': 28, 'hon_mirror': 44}.items():
        bk[k]['cost'] = c
    e = d['effects']
    e['status_qi'] = {"trigger": "status_applied", "conditions": {"family": "mark"}, "actions": [{"type": "restore_qi", "amount": 8}], "limits": {"icd": 0.4}, "description": "Gây Ấn (Kiếm Ấn hoặc Hồn Ấn) → hồi 8 linh lực, tối đa 2–3 lần/giây."}
    e['cycle_cd'] = {"trigger": "status_applied", "conditions": {"family": "mark"}, "actions": [{"type": "reduce_cooldown", "slot": "cong", "amount": 0.6}], "limits": {"icd": 0.7}, "description": "Gây Ấn → Công Pháp giảm 0,6 giây hồi chiêu, hồi 0,7 giây."}
    e['elem_cycle'] = {"trigger": "status_applied", "conditions": {"families": ["dot", "control"]}, "actions": [{"type": "restore_qi", "amount": 8}], "limits": {"icd": 0.5}, "description": "Gây sát thương theo thời gian hoặc khống chế (chảy máu, thiêu đốt, Hàn Khí) → hồi 8 linh lực, hồi 0,5 giây."}
    e['mark_burst'] = {"trigger": "status_stack_changed", "conditions": {"family": "mark", "min_stacks": 3}, "actions": [{"type": "damage", "amount": 30}], "limits": {"icd": 1.5}, "description": "Mục tiêu có ≥3 tầng Ấn (Kiếm Ấn hoặc Hồn Ấn) → đòn phụ 30 sát thương, hồi 1,5 giây; không tự kích hoạt lại."}
    e['blood_heal'] = {"trigger": "attack_hit", "conditions": {"tags_all": ["direct"], "target_family": "dot"}, "actions": [{"type": "heal", "amount": 3, "scale": 0.25}], "limits": {"icd": 0.5}, "description": "Đánh trực tiếp mục tiêu đang chịu sát thương theo thời gian (chảy máu, thiêu đốt) → hồi 3 khí huyết + 25% sát thương gây ra, hồi 0,5 giây."}
    e['break_heal'] = {"trigger": "attack_hit", "conditions": {"tags_all": ["direct"], "target_family": "debuff"}, "actions": [{"type": "heal", "amount": 3, "scale": 0.25}, {"type": "restore_qi", "amount": 3}], "limits": {"icd": 0.5}, "description": "Đánh trực tiếp mục tiêu đang bị Phá Giáp/Suy Yếu → hồi 3 khí huyết + 25% sát thương và 3 linh lực, hồi 0,5 giây."}
    e['kill_qi'] = {"trigger": "target_killed", "conditions": {}, "actions": [{"type": "restore_qi", "amount": 18}], "limits": {"icd": 0.5}, "description": "Hạ mục tiêu → hồi 18 linh lực, hồi 0,5 giây."}
    e['guard_counter'] = {"trigger": "guard_success", "conditions": {}, "actions": [{"type": "damage", "amount": 18}], "limits": {"icd": 1.5}, "description": "Hộ Thể chặn đòn → phản chấn 18 sát thương, hồi 1,5 giây; không kế thừa on-hit."}
    e['soul_qi'] = {"trigger": "attack_hit", "conditions": {"target_family": "mark", "tags_all": ["direct"]}, "actions": [{"type": "restore_qi", "amount": 4}], "limits": {"icd": 0.8}, "description": "Đánh trực tiếp mục tiêu mang Ấn → hồi 4 linh lực, hồi 0,8 giây."}
    e['dodge_heal'] = {"trigger": "perfect_dodge", "conditions": {}, "actions": [{"type": "heal", "amount": 0.06, "pct": True}], "limits": {"icd": 2}, "description": "Né hoàn hảo → hồi 6% khí huyết tối đa, hồi 2 giây."}
    e['dodge_surge'] = {"trigger": "perfect_dodge", "conditions": {}, "actions": [{"type": "status", "status": "surge", "target": "self", "stacks": 1}], "limits": {"icd": 1}, "description": "Né hoàn hảo → Thừa Thế 4 giây: Công Pháp và Pháp Bảo gây thêm 40% sát thương."}
    e['dodge_qi'] = {"trigger": "perfect_dodge", "conditions": {}, "actions": [{"type": "restore_qi", "amount": 0.04, "pct": True}], "limits": {"icd": 2.5}, "description": "Né hoàn hảo → hồi 4% linh lực tối đa, hồi 2,5 giây."}
    e['dodge_slow'] = {"trigger": "perfect_dodge", "conditions": {}, "actions": [{"type": "status", "status": "slow", "stacks": 1}], "limits": {"icd": 0.5}, "description": "Né hoàn hảo → kẻ vừa đánh bị Hàn Khí (kích hoạt cả Tâm Pháp nhận trạng thái bất lợi)."}
    e['dodge_weaken'] = {"trigger": "perfect_dodge", "conditions": {}, "actions": [{"type": "status", "status": "weaken", "stacks": 1}], "limits": {"icd": 1}, "description": "Né hoàn hảo → kẻ vừa đánh bị Suy Yếu 3 giây (đòn của nó yếu đi 25%)."}
    e['dodge_mark'] = {"trigger": "perfect_dodge", "conditions": {}, "actions": [{"type": "status", "status": "hon_an", "stacks": 2}], "limits": {"icd": 0.5}, "description": "Né hoàn hảo → kẻ vừa đánh mang 2 tầng Hồn Ấn."}
    e['pearl'] = {"trigger": "resource_spent", "conditions": {"resource": "qi", "min_amount": 40, "skill_type": "cong"}, "actions": [{"type": "restore_qi", "amount": 0, "scale": 0.3}, {"type": "reduce_cooldown", "slot": "than", "amount": 1.0}], "limits": {"icd": 1}, "description": "Một lần thi pháp thực trả ≥40 linh lực → hoàn 30% linh lực đã tiêu và giảm 1 giây hồi Thân Pháp; hồi nội bộ 1 giây."}
    e['sword_rain'] = {"trigger": "attack_hit", "conditions": {"tags_all": ["direct"]}, "actions": [{"type": "damage", "amount": 10}], "limits": {"icd": 1.0}, "description": "Đòn trực tiếp trúng → một thanh phi kiếm bổ thêm 10 sát thương, hồi 1 giây."}
    tam = {'kiem_heart': ['mark_burst'], 'kiem_flow': ['status_qi'], 'dao_blood': ['blood_heal'], 'dao_victory': ['kill_qi'],
           'ngu_cycle': ['elem_cycle'], 'ngu_wood': ['dodge_heal'], 'the_guard': ['dodge_guard', 'guard_counter'],
           'the_blood': ['break_heal'], 'hon_heart': ['cycle_cd'], 'hon_echo': ['summon_mark', 'soul_qi']}
    than = {'kiem_step': ['dodge_qi'], 'kiem_guard': ['dodge_guard'], 'dao_chase': ['dodge_surge'], 'dao_retreat': ['dodge_heal'],
            'ngu_earth': ['dodge_guard'], 'ngu_waterstep': ['dodge_slow'], 'the_step': ['dodge_guard', 'dodge_heal'],
            'the_leap': ['dodge_weaken'], 'hon_step': ['dodge_mark'], 'hon_mirror': ['summon_mark', 'dodge_qi']}
    for k, v in {**tam, **than}.items():
        bk[k]['effects'] = v
    # Sát thương có điều kiện theo HỌ trạng thái trên mục tiêu: chỉ phát huy khi Công Pháp/Thân Pháp cấp đúng họ đó.
    cond = {
        'kiem_heart': (['mark'], 1.25, 'Mục tiêu mang Ấn (Kiếm Ấn, Hồn Ấn): sát thương Công Pháp tăng 25%.'),
        'hon_heart': (['mark'], 1.2, 'Mục tiêu mang Ấn: sát thương Công Pháp tăng 20%.'),
        'hon_echo': (['mark'], 1.15, 'Mục tiêu mang Ấn: sát thương tăng 15%.'),
        'dao_blood': (['dot'], 1.25, 'Mục tiêu đang chảy máu hoặc thiêu đốt: sát thương Công Pháp tăng 25%.'),
        'ngu_cycle': (['dot', 'control'], 1.2, 'Mục tiêu đang chịu sát thương theo thời gian hoặc bị khống chế: sát thương tăng 20%.'),
        'the_blood': (['debuff'], 1.25, 'Mục tiêu đang bị Phá Giáp hoặc Suy Yếu: sát thương Công Pháp tăng 25%.'),
    }
    for k, (fams, mult, text) in cond.items():
        bk[k]['conditional'] = {'families': fams, 'damage_mult': mult, 'text': text}
    bk['kiem_step']['effects'] = ['dodge_qi']
    bk['the_leap']['effects'] = ['dodge_weaken', 'dodge_heal']
    bk['kiem_guard']['effects'] = ['dodge_guard', 'dodge_qi']
    bk['ngu_earth']['effects'] = ['dodge_guard', 'dodge_heal']
    a = d['affixes']
    a['opportunist'].update({'conditional': {'families': ['dot', 'control'], 'damage_mult': 1.2},
                             'description': 'Mục tiêu đang chịu sát thương theo thời gian hoặc bị khống chế: tăng 20% sát thương.'})
    a['finisher'].update({'conditional': {'families': ['mark'], 'min_total_stacks': 3, 'damage_mult': 1.35},
                          'description': 'Mục tiêu mang Ấn và từ 3 tầng bất lợi: tăng 35% sát thương, nhưng tăng 10% chi phí linh lực.'})
    # Dòng phụ "hồi theo sự kiện" phải nhẹ hơn hiệu ứng gốc của Tâm Pháp, tránh thiên vị chiêu đánh nhanh.
    e['status_qi_lite'] = {"trigger": "status_applied", "conditions": {"families": ["mark", "dot", "control"]}, "actions": [{"type": "restore_qi", "amount": 3}], "limits": {"icd": 1.2}, "description": "Gây Ấn, sát thương theo thời gian hoặc khống chế → hồi 3 linh lực, hồi 1,2 giây."}
    a['flow']['effects'] = ['status_qi_lite']
    a['flow']['description'] = 'Gây Ấn, sát thương theo thời gian hoặc khống chế → hồi 3 linh lực, hồi 1,2 giây.'
    e['crit_qi']['limits'] = {"icd": 2.5}
    e['crit_qi']['description'] = "Chí mạng → hồi 3 linh lực, hồi 2,5 giây."
    a['crit_qi']['description'] = "Đòn chí mạng → hồi 3 linh lực; hồi nội bộ 2,5 giây."
    a['efficient'].update({'damage_mult': 0.96, 'description': 'Giảm 8% chi phí linh lực, giảm 4% sát thương.'})
    eq = {x['id']: x for x in d['equipment']}
    eq['qi_pearl'].update({'cost': 30, 'cooldown': 1.2, 'damage': 18})
    eq['soul_bell'].update({'cost': 45, 'cooldown': 2, 'damage': 24})
    eq['nine_swords'].update({'cost': 55, 'cooldown': 6, 'damage': 16, 'effects': ['sword_rain']})
    save(d)


def apply_fit(mult):
    d = load()
    items = {x['id']: x for x in d['books'] + d['equipment']}
    for k, m in mult.items():
        items[k]['damage'] = round(float(items[k]['damage']) * m, 1)
    save(d)


if __name__ == '__main__':
    if sys.argv[1] == 'base':
        apply_base()
    elif sys.argv[1] == 'fit-apply':
        apply_fit(json.loads(sys.argv[2]))
