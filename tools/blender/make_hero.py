"""Dựng model nhân vật tu tiên (chibi) bằng Blender -> assets/models/hero.glb.

Chạy (cần module bpy, vd: python -m venv v && v/bin/pip install bpy):
    python tools/blender/make_hero.py [đường dẫn .glb]

Model gồm: thân + đầu + mặt (mắt nhiều lớp, mi, lông mày, má hồng...), tóc, các mảnh trang phục tách rời
(tên mảnh dạng <nhóm>__<chi tiết>, vd robe_long__skirt) để Godot bật/tắt theo bộ đồ, xương người (có xương phụ cho tóc dài,
áo choàng, dải đai, ngọc bội) và 3 animation: idle_loop, walk_loop, attack.
Mỗi vật liệu tên m_<vai trò> (m_robe, m_trim, m_hair...) để Godot đổi màu theo trang phục.
Toạ độ viết theo kiểu Godot (x phải, y lên, z ra trước) rồi đổi sang Blender trong hàm G().
"""
import math
import sys
import bpy   # phải import trước bmesh/mathutils
import bmesh
from mathutils import Euler, Matrix, Quaternion, Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else (sys.argv[1] if len(sys.argv) > 1 else "hero.glb")

HEAD_Y = 1.37   # tâm đầu


def G(x, y=None, z=None):
    """Toạ độ Godot (x, y lên, z ra trước) -> Blender (x, -z, y)."""
    if y is None:
        x, y, z = x
    return Vector((x, -z, y))


def H(x, y, z):
    """Toạ độ cục bộ của đầu -> toạ độ thế giới (kiểu Godot)."""
    return (x, y + HEAD_Y, z)


# ---------------------------------------------------------------- cảnh, vật liệu
bpy.ops.wm.read_factory_settings(use_empty=True)

ROLE_COLORS = {
    "skin": "f6d3b3", "skin_dark": "e2b08f", "hair": "3a2a2c", "robe": "3f86b5", "trim": "f0ead6", "inner": "e9f2f7",
    "shoe": "2d3a52", "sole": "e8e0cc", "eye": "2f6fb0", "eye_light": "7fb8ee", "ink": "1c1520", "white": "ffffff",
    "blush": "f2a09c", "mouth": "a05a5a", "gold": "e0b13f", "steel": "dfe9f2", "jade": "6fcf9a", "gem": "e6354e",
}
MATS = {}
for role, hexcol in ROLE_COLORS.items():
    m = bpy.data.materials.new("m_" + role)
    m.use_nodes = True
    r, g, b = (int(hexcol[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (r ** 2.2, g ** 2.2, b ** 2.2, 1.0)
    MATS[role] = m


# ---------------------------------------------------------------- xương
# tên: (đầu, đuôi, cha) theo toạ độ Godot
BONES = {
    "root": ((0, 0, 0), (0, 0.1, 0), None),
    "hips": ((0, 0.55, 0), (0, 0.62, 0), "root"),
    "spine": ((0, 0.62, 0), (0, 0.95, 0), "hips"),
    "neck": ((0, 0.95, 0), (0, 1.10, 0), "spine"),
    "head": ((0, 1.10, 0), (0, 1.75, 0), "neck"),
    "hair1": ((0, 1.45, -0.26), (0, 1.2, -0.3), "head"),
    "hair2": ((0, 1.2, -0.3), (0, 0.95, -0.3), "hair1"),
    "hair3": ((0, 0.95, -0.3), (0, 0.62, -0.3), "hair2"),
    "cape1": ((0, 0.98, -0.2), (0, 0.65, -0.22), "spine"),
    "cape2": ((0, 0.65, -0.22), (0, 0.2, -0.24), "cape1"),
    "tail_l": ((-0.06, 0.57, -0.2), (-0.06, 0.3, -0.2), "hips"),
    "tail_r": ((0.06, 0.57, -0.2), (0.06, 0.3, -0.2), "hips"),
    "pend_l": ((-0.27, 0.55, 0.13), (-0.27, 0.33, 0.13), "hips"),
    "pend_r": ((0.27, 0.55, 0.13), (0.27, 0.33, 0.13), "hips"),
}
for side, sx in (("l", -1.0), ("r", 1.0)):
    BONES[f"arm_{side}_up"] = ((sx * 0.26, 0.95, 0), (sx * 0.30, 0.75, 0), "spine")
    BONES[f"arm_{side}_lo"] = ((sx * 0.30, 0.75, 0), (sx * 0.315, 0.55, 0.0), f"arm_{side}_up")
    BONES[f"hand_{side}"] = ((sx * 0.315, 0.55, 0.0), (sx * 0.32, 0.45, 0.02), f"arm_{side}_lo")
    BONES[f"leg_{side}_up"] = ((sx * 0.1, 0.55, 0), (sx * 0.1, 0.3, 0), "hips")
    BONES[f"leg_{side}_lo"] = ((sx * 0.1, 0.3, 0), (sx * 0.1, 0.08, 0), f"leg_{side}_up")
    BONES[f"foot_{side}"] = ((sx * 0.1, 0.08, 0), (sx * 0.1, 0.04, 0.15), f"leg_{side}_lo")

arm_data = bpy.data.armatures.new("Armature")
ARM = bpy.data.objects.new("Armature", arm_data)
bpy.context.scene.collection.objects.link(ARM)
bpy.context.view_layer.objects.active = ARM
bpy.ops.object.mode_set(mode="EDIT")
for name, (head, tail, parent) in BONES.items():
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = G(head), G(tail)
    eb.roll = 0.0
for name, (_, _, parent) in BONES.items():
    if parent:
        arm_data.edit_bones[name].parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")

SEG = {n: (G(h), G(t)) for n, (h, t, _) in BONES.items()}   # đoạn xương (Blender) để tính trọng số


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def smooth_w(p, bones, radius=0.12):
    """Trọng số theo khoảng cách tới các đoạn xương (đủ cho vai/khuỷu/gối, không cần heat weights)."""
    ws = {}
    for n in bones:
        d = seg_dist(p, *SEG[n])
        w = max(0.0, 1.0 - d / radius) ** 2
        if w > 0.0005:
            ws[n] = w
    if not ws:
        n = min(bones, key=lambda k: seg_dist(p, *SEG[k]))
        ws[n] = 1.0
    top = sorted(ws.items(), key=lambda kv: -kv[1])[:3]
    s = sum(w for _, w in top)
    return {n: w / s for n, w in top}


# ---------------------------------------------------------------- dựng mesh
FLIPPED = []


def finish(name, bm, role, weights):
    """Tạo object từ bmesh; weights = tên xương (cứng) hoặc hàm vị trí -> {xương: trọng số}."""
    # đảm bảo pháp tuyến hướng ra ngoài (khối dựng bằng phép hoán đổi trục có thể bị ngược hướng mặt)
    bm.faces.ensure_lookup_table()
    centroid = sum((v.co for v in bm.verts), Vector()) / max(1, len(bm.verts))
    score = sum(f.normal.dot(f.calc_center_median() - centroid) * f.calc_area() for f in bm.faces)
    if score < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        FLIPPED.append(name)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(MATS[role])
    groups = {}
    for v in me.vertices:
        ws = {weights: 1.0} if isinstance(weights, str) else weights(v.co.copy())
        for bone, w in ws.items():
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([v.index], w, "REPLACE")
    obj.parent = ARM
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = ARM
    return obj


def rings_to_bm(rings, cap_start=True, cap_end=True):
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(vr[0])
    for i in range(len(vr) - 1):
        for j in range(n):
            bm.faces.new((vr[i][j], vr[i][(j + 1) % n], vr[i + 1][(j + 1) % n], vr[i + 1][j]))
    for flag, ring, flip in ((cap_start, vr[0], True), (cap_end, vr[-1], False)):
        if flag:
            c = bm.verts.new(sum((v.co for v in ring), Vector()) / n)
            for j in range(n):
                a, b = ring[j], ring[(j + 1) % n]
                bm.faces.new((c, b, a) if flip else (c, a, b))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def lathe(profile, segs=28, sx=1.0, sz=1.0, cx=0.0, cz=0.0, caps=True):
    """Mặt tròn xoay quanh trục đứng. profile = [(bán kính, y)] kiểu Godot, sx/sz = độ dẹt, (cx, cz) = tâm."""
    rings = []
    for r, y in profile:
        rings.append([G(cx + math.cos(2 * math.pi * k / segs) * r * sx, y, cz + math.sin(2 * math.pi * k / segs) * r * sz)
                      for k in range(segs)])
    return rings_to_bm(rings, caps, caps)


def tube(path, radii, segs=14, ellip=(1.0, 1.0), caps=True):
    """Ống đi theo đường path (toạ độ Godot), bán kính thay đổi dần; ellip = độ dẹt (u, v) của tiết diện."""
    pts = [Vector(p) for p in path]
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(t.y) > 0.7 else Vector((0, 1, 0))
        u = t.cross(ref).normalized()
        v = t.cross(u).normalized()
        r = radii[i]
        rings.append([G(p + u * math.cos(2 * math.pi * k / segs) * r * ellip[0] + v * math.sin(2 * math.pi * k / segs) * r * ellip[1])
                      for k in range(segs)])
    return rings_to_bm(rings, caps, caps)


def ellipsoid(center, radii, rot=(0, 0, 0), seg=20, ring=12, shape=None):
    """Mặt cầu dẹt. center/radii kiểu Godot; rot = góc Euler (độ) quanh các trục Godot; shape(v) chỉnh hình ở toạ độ cục bộ."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=ring, radius=1.0)
    rot_m = Euler([math.radians(a) for a in rot], "XYZ").to_matrix()
    for v in bm.verts:
        p = Vector((v.co.x * radii[0], v.co.z * radii[1], v.co.y * radii[2]))   # cầu đơn vị: z là trục dọc của uvsphere
        if shape:
            p = shape(p)
        p = rot_m @ p + Vector(center)
        v.co = G(p)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def torus(center, big, small, rot=(0, 0, 0), segs=20, tsegs=8):
    rot_m = Euler([math.radians(a) for a in rot], "XYZ").to_matrix()
    rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        ring = []
        for j in range(tsegs):
            b = 2 * math.pi * j / tsegs
            p = Vector(((big + small * math.cos(b)) * math.cos(a), small * math.sin(b), (big + small * math.cos(b)) * math.sin(a)))
            ring.append(G(rot_m @ p + Vector(center)))
        rings.append(ring)
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    for i in range(segs):
        for j in range(tsegs):
            bm.faces.new((vr[i][j], vr[(i + 1) % segs][j], vr[(i + 1) % segs][(j + 1) % tsegs], vr[i][(j + 1) % tsegs]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def slab(center, size, cuts=0, rot=(0, 0, 0)):
    """Tấm hộp (cắt nhỏ theo chiều cao để uốn được khi animation)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    if cuts:
        bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.5],
                                  cuts=cuts, use_grid_fill=True)
    rot_m = Euler([math.radians(a) for a in rot], "XYZ").to_matrix()
    for v in bm.verts:
        p = Vector((v.co.x * size[0], v.co.z * size[1], v.co.y * size[2]))
        # bo tròn mép nhẹ: kéo đỉnh về phía tâm để pháp tuyến mượt khi shade smooth
        v.co = G(rot_m @ p + Vector(center))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# ---------------------------------------------------------------- THÂN
TORSO_PROFILE = [(0.001, 0.50), (0.10, 0.51), (0.162, 0.56), (0.17, 0.70), (0.195, 0.86), (0.185, 0.97), (0.11, 1.03), (0.07, 1.06), (0.001, 1.07)]
finish("body__torso", lathe(TORSO_PROFILE, sz=0.9), "skin", lambda p: smooth_w(p, ["hips", "spine", "neck"], 0.2))
finish("body__neck", tube([(0, 1.0, 0), (0, 1.12, 0)], [0.065, 0.062]), "skin", "neck")


def head_shape(p):
    s = max(0.0, min(1.0, (p.y + 0.05) / -0.27))
    k = 1.0 - 0.17 * s * s
    return Vector((p.x * k, p.y, p.z * k * (1.0 - 0.02 * s)))


finish("body__head", ellipsoid(H(0, 0, 0), (0.34, 0.31, 0.32), seg=40, ring=26, shape=head_shape), "skin", "head")
for sx in (-1, 1):
    finish(f"body__ear{sx}", ellipsoid(H(sx * 0.325, -0.03, -0.01), (0.026, 0.05, 0.04)), "skin", "head")

LIMBS = {
    "l": {"arm": [(-0.26, 0.95, 0), (-0.295, 0.80, 0), (-0.305, 0.75, 0), (-0.315, 0.60, 0.0)], "ar": [0.062, 0.055, 0.052, 0.045]},
    "r": {"arm": [(0.26, 0.95, 0), (0.295, 0.80, 0), (0.305, 0.75, 0), (0.315, 0.60, 0.0)], "ar": [0.062, 0.055, 0.052, 0.045]},
}
for side, sx in (("l", -1.0), ("r", 1.0)):
    arm_b = [f"arm_{side}_up", f"arm_{side}_lo", f"hand_{side}", "spine"]
    finish(f"body__arm_{side}", tube(LIMBS[side]["arm"], LIMBS[side]["ar"]), "skin", lambda p, b=arm_b: smooth_w(p, b[:3], 0.1))
    hand_b = f"hand_{side}"
    finish(f"body__hand_{side}", ellipsoid((sx * 0.318, 0.51, 0.012), (0.052, 0.07, 0.04)), "skin", hand_b)
    finish(f"body__thumb_{side}", ellipsoid((sx * 0.268, 0.53, 0.04), (0.018, 0.04, 0.02), rot=(0, 0, sx * 30)), "skin", hand_b)
    leg_b = [f"leg_{side}_up", f"leg_{side}_lo", f"foot_{side}"]
    finish(f"body__leg_{side}", tube([(sx * 0.1, 0.56, 0), (sx * 0.1, 0.32, 0), (sx * 0.1, 0.28, 0), (sx * 0.1, 0.08, 0)],
                                     [0.085, 0.07, 0.068, 0.052]), "skin", lambda p, b=leg_b: smooth_w(p, b[:2], 0.1))

# ---------------------------------------------------------------- GIÀY
for side, sx in (("l", -1.0), ("r", 1.0)):
    fb = f"foot_{side}"
    finish(f"shoes__boot_{side}", ellipsoid((sx * 0.1, 0.075, 0.04), (0.075, 0.075, 0.135)), "shoe", fb)
    finish(f"shoes__cuff_{side}", tube([(sx * 0.1, 0.17, 0), (sx * 0.1, 0.1, 0)], [0.068, 0.07]), "shoe", fb)
    finish(f"shoes__sole_{side}", ellipsoid((sx * 0.1, 0.022, 0.045), (0.08, 0.022, 0.15)), "sole", fb)
    finish(f"shoes__toe_{side}", ellipsoid((sx * 0.1, 0.09, 0.15), (0.04, 0.035, 0.04)), "sole", fb)

# ---------------------------------------------------------------- MẶT (cứng theo xương đầu)
for sx in (-1.0, 1.0):
    ex = sx * 0.125
    tag = "l" if sx < 0 else "r"
    finish(f"face__eye_base_{tag}", ellipsoid(H(ex, -0.035, 0.281), (0.06, 0.084, 0.027)), "ink", "head")
    finish(f"face__iris_{tag}", ellipsoid(H(ex, -0.05, 0.296), (0.043, 0.056, 0.016)), "eye", "head")
    finish(f"face__glow_{tag}", ellipsoid(H(ex, -0.088, 0.30), (0.033, 0.02, 0.012)), "eye_light", "head")
    finish(f"face__pupil_{tag}", ellipsoid(H(ex, -0.046, 0.304), (0.017, 0.03, 0.01)), "ink", "head")
    finish(f"face__hl1_{tag}", ellipsoid(H(ex + sx * 0.021, -0.001, 0.309), (0.017, 0.017, 0.008)), "white", "head")
    finish(f"face__hl2_{tag}", ellipsoid(H(ex - sx * 0.018, -0.085, 0.306), (0.009, 0.009, 0.006)), "white", "head")
    finish(f"face__lash_{tag}", tube([H(ex - sx * 0.055, 0.035, 0.30), H(ex, 0.049, 0.304), H(ex + sx * 0.058, 0.03, 0.296)],
                                     [0.009, 0.011, 0.007], 8, (1.0, 0.7)), "ink", "head")
    finish(f"face__brow_{tag}", tube([H(ex - sx * 0.05, 0.097 + 0.01 * sx * -1 * 0, 0.288), H(ex + sx * 0.05, 0.105, 0.286)],
                                     [0.011, 0.009], 8, (1.0, 0.8)), "hair", "head")
    finish(f"face__blush_{tag}", ellipsoid(H(sx * 0.2, -0.1, 0.235), (0.045, 0.028, 0.012), rot=(0, sx * 38, 0)), "blush", "head")
finish("face__nose", ellipsoid(H(0, -0.077, 0.316), (0.013, 0.013, 0.012)), "skin_dark", "head")
finish("face__mouth", tube([H(-0.025, -0.125, 0.3), H(0, -0.131, 0.302), H(0.025, -0.125, 0.3)], [0.006, 0.007, 0.006], 8), "mouth", "head")

# ---------------------------------------------------------------- TÓC
finish("hair_base__cap", ellipsoid(H(0, 0.055, -0.055), (0.358, 0.335, 0.345), seg=36, ring=22), "hair", "head")
for i, x in enumerate([-0.24, -0.16, -0.08, 0.0, 0.08, 0.16, 0.24]):
    h = [0.2, 0.24, 0.22, 0.2, 0.22, 0.24, 0.2][i]
    yc = math.sqrt(0.335 ** 2 - x * x) * 0.93 - h * 0.5
    zc = math.sqrt(max(0.335 ** 2 - x * x - yc * yc, 0.0))
    top = H(x, yc + h * 0.5, zc - 0.01)
    tip = H(x * 1.05, yc - h * 0.5, zc + 0.045)
    finish(f"hair_base__bang{i}", tube([top, ((top[0] + tip[0]) / 2, (top[1] + tip[1]) / 2, (top[2] + tip[2]) / 2 + 0.015), tip],
                                       [0.06, 0.045, 0.002], 10), "hair", "head")
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    finish(f"hair_base__lock_{tag}", tube([H(sx * 0.3, 0.12, 0.04), H(sx * 0.31, -0.05, 0.05), H(sx * 0.3, -0.2, 0.07)], [0.05, 0.052, 0.012], 10),
           "hair", "head")
    finish(f"hair_base__lockf_{tag}", tube([H(sx * 0.26, 0.1, 0.15), H(sx * 0.27, -0.06, 0.16), H(sx * 0.265, -0.2, 0.18)], [0.032, 0.034, 0.006], 8),
           "hair", "head")
finish("hair_short__tuft", tube([H(0.03, 0.34, 0.08), H(0.05, 0.43, 0.12), H(0.08, 0.47, 0.17)], [0.03, 0.02, 0.003], 8), "hair", "head")
# búi tóc
finish("hair_bun__bun", ellipsoid(H(0, 0.4, -0.06), (0.14, 0.12, 0.14)), "hair", "head")
finish("hair_bun__band", tube([H(0, 0.29, -0.06), H(0, 0.33, -0.06)], [0.105, 0.105], 20), "trim", "head")
finish("hair_bun__pin", tube([H(-0.19, 0.4, -0.06), H(0.19, 0.4, -0.06)], [0.012, 0.012], 8), "gold", "head")
finish("hair_bun__tuft", tube([H(0.03, 0.5, 0.08), H(0.05, 0.57, 0.11), H(0.08, 0.6, 0.15)], [0.03, 0.02, 0.003], 8), "hair", "head")
# tóc dài: ôm sau đầu và rủ theo chuỗi xương hair1..3
HAIR_PATH = [H(0, 0.1, -0.18), (0, 1.25, -0.27), (0, 1.0, -0.29), (0, 0.75, -0.28), (0, 0.55, -0.27)]


def hair_w(p):
    y = p.z   # Blender z = Godot y
    if y > 1.25:
        return {"head": 1.0}
    if y > 1.0:
        t = (1.25 - y) / 0.25
        return {"hair1": 1.0 - 0.5 * t, "hair2": 0.5 * t}
    if y > 0.75:
        t = (1.0 - y) / 0.25
        return {"hair2": 1.0 - 0.5 * t, "hair3": 0.5 * t}
    return {"hair3": 1.0}


finish("hair_long__back", tube(HAIR_PATH, [0.2, 0.21, 0.2, 0.17, 0.1], 18, (1.15, 0.7)), "hair", hair_w)
for k, (x, l) in enumerate([(-0.1, 0.2), (0.0, 0.27), (0.1, 0.2)]):
    finish(f"hair_long__tip{k}", tube([(x, 0.58, -0.27), (x, 0.58 - l * 0.5, -0.27), (x, 0.58 - l, -0.27)], [0.07, 0.045, 0.002], 8), "hair", "hair3")
finish("hair_long__tie", tube([(0, 1.13, -0.27), (0, 1.07, -0.27)], [0.115, 0.115], 20, (1.1, 0.8)), "trim", hair_w)
# tóc gai
for i in range(6):
    a = 2 * math.pi * i / 6
    base = H(math.sin(a) * 0.2, 0.3, math.cos(a) * 0.2 - 0.06)
    tip = H(math.sin(a) * 0.3, 0.55, math.cos(a) * 0.3 - 0.06)
    finish(f"hair_spike__s{i}", tube([base, tip], [0.07, 0.002], 8), "hair", "head")
finish("hair_spike__top", tube([H(0, 0.38, -0.06), H(0, 0.82, -0.06)], [0.09, 0.002], 8), "hair", "head")
# phụ kiện đầu
finish("head_band__band", tube([H(0, 0.12, 0), H(0, 0.18, 0)], [0.338, 0.338], 36, (1.07, 1.04)), "trim", "head")
finish("head_crown__base", tube([H(0, 0.34, -0.03), H(0, 0.44, -0.03)], [0.14, 0.1], 20), "trim", "head")
finish("head_crown__pin", tube([H(-0.22, 0.4, -0.03), H(0.22, 0.4, -0.03)], [0.014, 0.014], 8), "trim", "head")
finish("head_crown__gem", ellipsoid(H(0, 0.2, 0.29), (0.032, 0.032, 0.02)), "gem", "head")

# ---------------------------------------------------------------- ÁO
torso_w = lambda p: smooth_w(p, ["hips", "spine", "neck"], 0.2)
finish("robe_top__chest", lathe([(r + 0.012, y) for r, y in TORSO_PROFILE[1:-1]], sz=0.9), "robe", torso_w)
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    finish(f"robe_top__lapel_{tag}", tube([(sx * 0.1, 1.0, 0.15), (sx * 0.06, 0.9, 0.185), (sx * 0.02, 0.8, 0.2), (0, 0.7, 0.205)], [0.03, 0.03, 0.028, 0.026], 10, (1.0, 0.3)),
           "trim", torso_w)
finish("robe_top__collar_in", tube([(0, 1.02, 0), (0, 1.075, 0)], [0.118, 0.12], 24), "inner", "neck")
finish("robe_top__collar", tube([(0, 1.0, 0), (0, 1.07, 0)], [0.108, 0.112], 24), "trim", "neck")
finish("robe_top__sash", lathe([(0.195, 0.55), (0.215, 0.55), (0.215, 0.64), (0.195, 0.64)], sz=0.92, caps=False), "trim", "hips")
finish("robe_top__knot", ellipsoid((0, 0.6, 0.2), (0.05, 0.05, 0.035)), "trim", "hips")
finish("robe_top__bow", ellipsoid((0, 0.6, -0.2), (0.04, 0.04, 0.03)), "trim", "hips")
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    finish(f"robe_top__loop_{tag}", ellipsoid((sx * 0.075, 0.61, -0.2), (0.07, 0.04, 0.02), rot=(0, 0, sx * 22)), "trim", "hips")
    finish(f"robe_top__tail_{tag}", tube([(sx * 0.06, 0.6, -0.205), (sx * 0.06, 0.45, -0.205), (sx * 0.06, 0.3, -0.205)], [0.027, 0.027, 0.02], 8, (1.0, 0.3)),
           "trim", lambda p, n=f"tail_{tag}": {"hips": 0.0001, n: 1.0} if p.z < 0.55 else {"hips": 1.0})


def skirt_w(p):
    """Váy: phần trên theo hông, phần dưới theo hai đùi (trái/phải) để váy ôm chân khi bước."""
    t = max(0.0, min(1.0, (0.58 - p.z) / 0.45))
    side = "leg_l_up" if p.x < 0 else "leg_r_up"
    wx = max(0.0, min(1.0, abs(p.x) / 0.2))
    return {"hips": 1.0 - 0.7 * t * wx, side: 0.7 * t * wx} if t * wx > 0.01 else {"hips": 1.0}


finish("robe_long__skirt", lathe([(0.205, 0.58), (0.23, 0.46), (0.27, 0.3), (0.32, 0.17), (0.36, 0.08), (0.36, 0.05)], sz=1.0, caps=False), "robe", skirt_w)
finish("robe_long__petti", lathe([(0.34, 0.08), (0.385, 0.07), (0.39, 0.035), (0.35, 0.03)], caps=False), "inner", skirt_w)
finish("robe_long__hem", lathe([(0.325, 0.16), (0.362, 0.15), (0.368, 0.1), (0.33, 0.1)], caps=False), "trim", skirt_w)
finish("robe_long__panel", tube([(0, 0.57, 0.205), (0, 0.4, 0.26), (0, 0.17, 0.33)], [0.07, 0.07, 0.075], 10, (1.0, 0.22)), "inner", skirt_w)
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    finish(f"robe_long__cloud_{tag}", ellipsoid((sx * 0.17, 0.3, 0.255), (0.045, 0.045, 0.012), rot=(0, sx * 33, 0)), "trim", skirt_w)
    finish(f"robe_long__cloud2_{tag}", ellipsoid((sx * 0.215, 0.27, 0.215), (0.03, 0.03, 0.01), rot=(0, sx * 45, 0)), "trim", skirt_w)
finish("robe_short__skirt", lathe([(0.205, 0.6), (0.23, 0.5), (0.28, 0.4), (0.285, 0.38)], caps=False), "robe", skirt_w)
finish("robe_short__hem", lathe([(0.268, 0.43), (0.285, 0.41), (0.287, 0.37), (0.268, 0.37)], caps=False), "trim", skirt_w)

# tay áo
for side, sx in (("l", -1.0), ("r", 1.0)):
    ab = [f"arm_{side}_up", f"arm_{side}_lo", f"hand_{side}"]
    wide = [(sx * 0.26, 0.96, 0), (sx * 0.295, 0.8, 0), (sx * 0.31, 0.7, 0), (sx * 0.32, 0.6, 0), (sx * 0.325, 0.55, 0)]
    finish(f"sleeve_wide__sleeve_{side}", tube(wide, [0.082, 0.1, 0.135, 0.165, 0.165], 20), "robe", lambda p, b=ab: smooth_w(p, b[:2], 0.1))
    finish(f"sleeve_wide__cuff_{side}", tube([(sx * 0.32, 0.585, 0), (sx * 0.325, 0.545, 0)], [0.168, 0.168], 20), "trim", lambda p, b=ab: smooth_w(p, b[:2], 0.1))
    finish(f"sleeve_wide__lining_{side}", tube([(sx * 0.325, 0.552, 0), (sx * 0.326, 0.54, 0)], [0.14, 0.14], 20), "inner", lambda p, b=ab: smooth_w(p, b[:2], 0.1))
    nar = [(sx * 0.26, 0.96, 0), (sx * 0.295, 0.8, 0), (sx * 0.305, 0.74, 0), (sx * 0.31, 0.66, 0)]
    finish(f"sleeve_narrow__sleeve_{side}", tube(nar, [0.074, 0.07, 0.07, 0.07], 16), "robe", lambda p, b=ab: smooth_w(p, b[:2], 0.1))
    finish(f"sleeve_narrow__cuff_{side}", tube([(sx * 0.309, 0.68, 0), (sx * 0.312, 0.645, 0)], [0.076, 0.076], 16), "trim", lambda p, b=ab: smooth_w(p, b[:2], 0.1))

# ---------------------------------------------------------------- ĐỒ SAU LƯNG
def cape_w(p):
    y = p.z
    t = max(0.0, min(1.0, (0.98 - y) / 0.5))
    return {"cape1": 1.0 - t, "cape2": t} if 0.01 < t < 0.99 else ({"cape1": 1.0} if t <= 0.01 else {"cape2": 1.0})


finish("back_cape__lining", slab((0, 0.58, -0.21), (0.5, 0.85, 0.028), cuts=6), "trim", cape_w)
finish("back_cape__outer", slab((0, 0.58, -0.232), (0.45, 0.8, 0.028), cuts=6), "robe", cape_w)
finish("back_sword__blade", slab((0, 0.82, -0.31), (0.05, 0.85, 0.02), rot=(0, 0, 38)), "steel", "spine")
finish("back_sword__guard", slab((-0.09, 0.51, -0.31), (0.2, 0.04, 0.04), rot=(0, 0, 38)), "gold", "spine")
finish("back_sword__grip", slab((-0.13, 0.4, -0.31), (0.05, 0.2, 0.05), rot=(0, 0, 38)), "trim", "spine")
for k in (0, 1):
    pass

# ---------------------------------------------------------------- PHỤ KIỆN HÔNG (mỗi bên 1 bộ; Godot chọn bên nào hiện)
for side, sx in (("l", -1.0), ("r", 1.0)):
    pb = f"pend_{side}"
    finish(f"acc_pouch_{side}__bag", ellipsoid((sx * 0.27, 0.45, 0.13), (0.055, 0.06, 0.035)), "skin_dark", pb)
    finish(f"acc_pouch_{side}__flap", ellipsoid((sx * 0.27, 0.5, 0.135), (0.058, 0.025, 0.04)), "shoe", pb)
    finish(f"acc_jade_{side}__rope", tube([(sx * 0.27, 0.55, 0.13), (sx * 0.27, 0.43, 0.13)], [0.006, 0.006], 6), "trim", pb)
    finish(f"acc_jade_{side}__ring", torus((sx * 0.27, 0.4, 0.13), 0.028, 0.012, rot=(90, 0, 0)), "jade", pb)
    for k, dx in enumerate((-0.014, 0, 0.014)):
        finish(f"acc_jade_{side}__tassel{k}", tube([(sx * 0.27 + dx, 0.37, 0.13), (sx * 0.27 + dx, 0.27, 0.13)], [0.008, 0.005], 6), "trim", pb)
    finish(f"acc_bell_{side}__rope", tube([(sx * 0.27, 0.55, 0.13), (sx * 0.27, 0.46, 0.13)], [0.005, 0.005], 6), "trim", pb)
    finish(f"acc_bell_{side}__bell", ellipsoid((sx * 0.27, 0.42, 0.13), (0.035, 0.035, 0.035)), "gold", pb)

# ---------------------------------------------------------------- ANIMATION
FPS = 30
bpy.context.scene.render.fps = FPS
ARM.animation_data_create()
rest_q = {n: ARM.data.bones[n].matrix_local.to_quaternion() for n in BONES}
rest_m = {n: ARM.data.bones[n].matrix_local.to_3x3() for n in BONES}
for pb in ARM.pose.bones:
    pb.rotation_mode = "QUATERNION"


def world_axis_rot(bone, axis, deg):
    """Quaternion cục bộ của xương tương ứng xoay `deg` độ quanh trục thế giới (kiểu Godot: 'x', 'y', 'z')."""
    ax = {"x": Vector((1, 0, 0)), "y": Vector((0, 0, 1)), "z": Vector((0, -1, 0))}[axis]   # Godot x,y,z -> Blender
    q_world = Quaternion(ax, math.radians(deg))
    q = rest_q[bone]
    return q.inverted() @ q_world @ q


def pose(frame, rots=None, locs=None):
    """rots: {xương: [(trục, độ), ...]}, locs: {xương: (dx, dy, dz) kiểu Godot}."""
    for pb in ARM.pose.bones:
        pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
        pb.location = Vector((0, 0, 0))
    for bone, ops in (rots or {}).items():
        q = Quaternion((1, 0, 0, 0))
        for axis, deg in ops:
            q = q @ world_axis_rot(bone, axis, deg)
        ARM.pose.bones[bone].rotation_quaternion = q
    for bone, off in (locs or {}).items():
        ARM.pose.bones[bone].location = rest_m[bone].inverted() @ G(*off)
    for pb in ARM.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def make_action(name, frames, builder):
    act = bpy.data.actions.new(name)
    ARM.animation_data.action = act
    for f in frames:
        rots, locs = builder(f)
        pose(f, rots, locs)
    track = ARM.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(frames[0]), act)
    strip.name = name
    ARM.animation_data.action = None
    return act


def idle(f):
    t = f / 60.0 * 2 * math.pi
    s = math.sin(t)
    return ({
        "spine": [("x", -1.2 * s)], "head": [("x", 0.8 * s), ("z", 1.2 * math.sin(t * 0.5))],
        "arm_l_up": [("z", -8 + 1.5 * s)], "arm_r_up": [("z", 8 - 1.5 * s)],
        "arm_l_lo": [("x", -6)], "arm_r_lo": [("x", -6)],
        "hair1": [("x", 3 + 2 * s)], "hair2": [("x", 4 + 3 * math.sin(t - 0.6))], "hair3": [("x", 5 + 4 * math.sin(t - 1.2))],
        "cape1": [("x", 3 + 1.5 * s)], "cape2": [("x", 5 + 3 * math.sin(t - 0.8))],
        "tail_l": [("x", 6 + 3 * math.sin(t - 0.4))], "tail_r": [("x", 6 + 3 * math.sin(t - 0.7))],
        "pend_l": [("x", 2 * math.sin(t))], "pend_r": [("x", 2 * math.sin(t - 0.5))],
    }, {"hips": (0, 0.006 * s, 0)})


def walk(f):
    t = f / 30.0 * 2 * math.pi
    s, c = math.sin(t), math.cos(t)
    bob = abs(math.sin(t)) * 0.045
    knee_l = max(0.0, math.sin(t + math.pi * 0.5)) * 45
    knee_r = max(0.0, math.sin(t - math.pi * 0.5)) * 45
    return ({
        "leg_l_up": [("x", -38 * s)], "leg_r_up": [("x", 38 * s)],
        "leg_l_lo": [("x", knee_l * 0.9)], "leg_r_lo": [("x", knee_r * 0.9)],
        "foot_l": [("x", -8 * s)], "foot_r": [("x", 8 * s)],
        "arm_l_up": [("x", 32 * s), ("z", -6)], "arm_r_up": [("x", -32 * s), ("z", 6)],
        "arm_l_lo": [("x", -18 - 10 * max(0.0, s))], "arm_r_lo": [("x", -18 - 10 * max(0.0, -s))],
        "spine": [("y", 7 * s), ("x", -4)], "hips": [("y", -5 * s)], "head": [("y", -4 * s), ("x", 3)],
        "hair1": [("x", 6 + 2 * math.sin(2 * t))], "hair2": [("x", 8 + 3 * math.sin(2 * t - 0.8))], "hair3": [("x", 10 + 4 * math.sin(2 * t - 1.6))],
        "cape1": [("x", 8 + 2 * math.sin(2 * t - 0.4))], "cape2": [("x", 12 + 4 * math.sin(2 * t - 1.1))],
        "tail_l": [("x", 20 + 6 * math.sin(2 * t))], "tail_r": [("x", 20 + 6 * math.sin(2 * t - 0.5))],
        "pend_l": [("x", -10 + 8 * math.sin(2 * t))], "pend_r": [("x", -10 + 8 * math.sin(2 * t - 0.6))],
    }, {"hips": (0, bob, 0)})


def attack(f):
    u = f / 18.0
    if u < 0.3:
        k = u / 0.3
        up, lo, tw = -170 * k, -50 * k, -18 * k
    elif u < 0.6:
        k = (u - 0.3) / 0.3
        up, lo, tw = -170 + 235 * k, -50 + 45 * k, -18 + 36 * k
    else:
        k = (u - 0.6) / 0.4
        up, lo, tw = 65 * (1 - k), -5 * (1 - k), 18 * (1 - k)
    return ({
        "arm_r_up": [("x", up), ("z", 10)], "arm_r_lo": [("x", lo)], "spine": [("y", tw), ("x", -5 * math.sin(u * math.pi))],
        "arm_l_up": [("z", -14), ("x", 10 * math.sin(u * math.pi))], "head": [("y", -tw * 0.4)],
        "hair1": [("x", 4)], "hair2": [("x", 6 + 6 * math.sin(u * math.pi))], "hair3": [("x", 8 + 8 * math.sin(u * math.pi))],
        "cape2": [("x", 8 + 10 * math.sin(u * math.pi))],
    }, {})


make_action("idle_loop", list(range(0, 61, 5)), idle)
make_action("walk_loop", list(range(0, 31, 2)), walk)
make_action("attack", list(range(0, 19, 2)), attack)
# khung cuối trùng khung đầu để vòng lặp liền mạch
pose(0, *idle(0))   # đưa về tư thế nghỉ (không giữ khoá)

for bone_name in list(BONES):
    pass

bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, 60

# ---------------------------------------------------------------- XUẤT
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", export_yup=True, export_apply=False, export_skins=True,
    export_animations=True, export_animation_mode="NLA_TRACKS", export_materials="EXPORT",
    export_image_format="NONE", export_cameras=False, export_lights=False, export_extras=False,
)
print("lật pháp tuyến:", len(FLIPPED), FLIPPED[:12])
print("OK ->", OUT, "| objects:", len([o for o in bpy.data.objects if o.type == "MESH"]))
