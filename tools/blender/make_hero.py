"""Dựng model nhân vật tu tiên (tỉ lệ người thật, ~7,5 đầu, cao 1,75 m) bằng Blender -> assets/models/hero.glb.

Chạy (cần module bpy, vd: python -m venv v && v/bin/pip install bpy):
    python tools/blender/make_hero.py [đường dẫn .glb]

Model gồm: thân (vai, ngực, eo, hông, tay chân có khớp), đầu + mặt (mắt hạnh nhân, mi, lông mày, sống mũi, môi, tai), tóc,
các mảnh trang phục tách rời (tên mảnh dạng <nhóm>__<chi tiết>, vd robe_long__skirt) để Godot bật/tắt theo bộ đồ,
xương người (có xương phụ cho tóc dài, áo choàng, dải đai, ngọc bội) và 3 animation: idle_loop, walk_loop, attack.
Mỗi vật liệu tên m_<vai trò> (m_robe, m_trim, m_hair...) để Godot đổi màu theo trang phục.
Toạ độ tính bằng mét, viết theo kiểu Godot (x phải, y lên, z ra trước) rồi đổi sang Blender trong hàm G().
"""
import math
import sys
import bpy   # phải import trước bmesh/mathutils
import bmesh
from mathutils import Euler, Quaternion, Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else (sys.argv[1] if len(sys.argv) > 1 else "hero.glb")

HY = 1.635   # cao độ tâm đầu


def G(x, y=None, z=None):
    """Toạ độ Godot (x, y lên, z ra trước) -> Blender (x, -z, y)."""
    if y is None:
        x, y, z = x
    return Vector((x, -z, y))


def H(x, y, z):
    """Toạ độ cục bộ của đầu (gốc ở tâm đầu) -> toạ độ thế giới (kiểu Godot)."""
    return (x, y + HY, z)


def clamp01(v):
    return max(0.0, min(1.0, v))


# ---------------------------------------------------------------- cảnh, vật liệu
bpy.ops.wm.read_factory_settings(use_empty=True)

ROLE_COLORS = {
    "skin": "e8bd9a", "skin_dark": "d2a07e", "hair": "3a2a2c", "robe": "3f86b5", "trim": "f0ead6", "inner": "e9f2f7",
    "shoe": "2d3a52", "sole": "e8e0cc", "eye": "4a3322", "eye_light": "7fb8ee", "ink": "1c1520", "white": "f4efe8",
    "blush": "f2a09c", "mouth": "b86a68", "gold": "e0b13f", "steel": "dfe9f2", "jade": "6fcf9a", "gem": "e6354e",
    "pants": "23293a", "hat": "c8a96a", "gourd": "c98a3c", "bamboo": "8aa860",
}
MATS = {}
for role, hexcol in ROLE_COLORS.items():
    m = bpy.data.materials.new("m_" + role)
    m.use_nodes = True
    r, g, b = (int(hexcol[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (r ** 2.2, g ** 2.2, b ** 2.2, 1.0)
    MATS[role] = m


# ---------------------------------------------------------------- xương (đầu, đuôi, cha) theo toạ độ Godot
BONES = {
    "root": ((0, 0, 0), (0, 0.1, 0), None),
    "hips": ((0, 0.95, 0), (0, 1.05, 0), "root"),
    "spine": ((0, 1.05, 0), (0, 1.4, 0), "hips"),
    "neck": ((0, 1.4, 0), (0, 1.52, 0), "spine"),
    "head": ((0, 1.52, 0), (0, 1.78, 0), "neck"),
    "hair1": ((0, 1.7, -0.1), (0, 1.55, -0.13), "head"),
    "hair2": ((0, 1.55, -0.13), (0, 1.35, -0.14), "hair1"),
    "hair3": ((0, 1.35, -0.14), (0, 1.1, -0.12), "hair2"),
    "cape1": ((0, 1.44, -0.11), (0, 1.05, -0.13), "spine"),
    "cape2": ((0, 1.05, -0.13), (0, 0.55, -0.14), "cape1"),
    "tail_l": ((-0.04, 1.06, -0.12), (-0.04, 0.8, -0.12), "hips"),
    "tail_r": ((0.04, 1.06, -0.12), (0.04, 0.8, -0.12), "hips"),
    "pend_l": ((-0.19, 1.06, 0.07), (-0.19, 0.86, 0.07), "hips"),
    "pend_r": ((0.19, 1.06, 0.07), (0.19, 0.86, 0.07), "hips"),
}
for side, sx in (("l", -1.0), ("r", 1.0)):
    BONES[f"arm_{side}_up"] = ((sx * 0.2, 1.42, 0), (sx * 0.225, 1.12, 0), "spine")
    BONES[f"arm_{side}_lo"] = ((sx * 0.225, 1.12, 0), (sx * 0.235, 0.87, 0.0), f"arm_{side}_up")
    BONES[f"hand_{side}"] = ((sx * 0.235, 0.87, 0.0), (sx * 0.24, 0.7, 0.01), f"arm_{side}_lo")
    BONES[f"leg_{side}_up"] = ((sx * 0.09, 0.95, 0), (sx * 0.095, 0.5, 0), "hips")
    BONES[f"leg_{side}_lo"] = ((sx * 0.095, 0.5, 0), (sx * 0.09, 0.08, 0), f"leg_{side}_up")
    BONES[f"foot_{side}"] = ((sx * 0.09, 0.08, 0), (sx * 0.09, 0.03, 0.14), f"leg_{side}_lo")

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


def lathe(profile, segs=32, sx=1.0, sz=1.0, cx=0.0, cz=0.0, caps=True):
    """Mặt tròn xoay quanh trục đứng. profile = [(bán kính, y)], sx/sz = độ dẹt, (cx, cz) = tâm."""
    rings = []
    for r, y in profile:
        rings.append([G(cx + math.cos(2 * math.pi * k / segs) * r * sx, y, cz + math.sin(2 * math.pi * k / segs) * r * sz)
                      for k in range(segs)])
    return rings_to_bm(rings, caps, caps)


def tube(path, radii, segs=14, ellip=(1.0, 1.0), caps=True):
    """Ống đi theo đường path, bán kính thay đổi dần; ellip = độ dẹt (u, v) của tiết diện."""
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
    """Mặt cầu dẹt. center/radii kiểu Godot; rot = góc Euler (độ) quanh các trục Godot; shape(p) chỉnh hình ở toạ độ cục bộ."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=ring, radius=1.0)
    rot_m = Euler([math.radians(a) for a in rot], "XYZ").to_matrix()
    for v in bm.verts:
        p = Vector((v.co.x * radii[0], v.co.z * radii[1], v.co.y * radii[2]))   # cầu đơn vị: z là trục dọc của uvsphere
        if shape:
            p = shape(p)
        v.co = G(rot_m @ p + Vector(center))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def torus(center, big, small, rot=(0, 0, 0), segs=20, tsegs=8):
    rot_m = Euler([math.radians(a) for a in rot], "XYZ").to_matrix()
    bm = bmesh.new()
    vr = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        ring = []
        for j in range(tsegs):
            b = 2 * math.pi * j / tsegs
            p = Vector(((big + small * math.cos(b)) * math.cos(a), small * math.sin(b), (big + small * math.cos(b)) * math.sin(a)))
            ring.append(bm.verts.new(G(rot_m @ p + Vector(center))))
        vr.append(ring)
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
        v.co = G(rot_m @ p + Vector(center))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# ================================================================ THÂN
# Thân: tiết diện elip (x = nửa rộng, z = nửa sâu = 0.68 * x). Hông rộng, eo thon, ngực nở, vai.
TORSO = [(0.001, 0.86), (0.11, 0.88), (0.16, 0.93), (0.172, 1.0), (0.155, 1.08), (0.143, 1.13), (0.15, 1.2), (0.163, 1.29),
         (0.172, 1.37), (0.165, 1.43), (0.1, 1.47), (0.058, 1.5), (0.001, 1.52)]
TORSO_SZ = 0.68
torso_w = lambda p: smooth_w(p, ["hips", "spine", "neck"], 0.25)
finish("body__torso", lathe(TORSO, sz=TORSO_SZ), "skin", torso_w)
finish("body__neck", tube([(0, 1.47, 0), (0, 1.56, 0.005)], [0.056, 0.052]), "skin", "neck")
for sx in (-1.0, 1.0):
    finish(f"body__delt{int(sx)}", ellipsoid((sx * 0.192, 1.388, 0), (0.05, 0.058, 0.05)), "skin", "spine")


def head_shape(p):
    """Đầu: hàm dưới thon lại, cằm nhô ra trước một chút."""
    s = clamp01((-p.y - 0.03) / 0.09)
    k = 1.0 - 0.3 * s * s
    return Vector((p.x * k, p.y, p.z * k + 0.012 * s))


finish("body__head", ellipsoid(H(0, 0, 0), (0.078, 0.117, 0.097), seg=44, ring=30, shape=head_shape), "skin", "head")
for sx in (-1, 1):
    finish(f"body__ear{sx}", ellipsoid(H(sx * 0.077, -0.005, -0.005), (0.009, 0.027, 0.018), rot=(0, sx * 12, 0)), "skin", "head")

for side, sx in (("l", -1.0), ("r", 1.0)):
    arm_b = [f"arm_{side}_up", f"arm_{side}_lo", f"hand_{side}"]
    arm_path = [(sx * 0.2, 1.41, 0), (sx * 0.212, 1.27, 0), (sx * 0.222, 1.14, 0), (sx * 0.229, 1.0, 0), (sx * 0.235, 0.88, 0)]
    finish(f"body__arm_{side}", tube(arm_path, [0.054, 0.048, 0.042, 0.038, 0.029]), "skin", lambda p, b=arm_b: smooth_w(p, b, 0.12))
    hb = f"hand_{side}"
    finish(f"body__palm_{side}", ellipsoid((sx * 0.239, 0.815, 0.004), (0.037, 0.058, 0.017)), "skin", hb)
    finish(f"body__fingers_{side}", tube([(sx * 0.24, 0.78, 0.01), (sx * 0.242, 0.72, 0.014)], [0.031, 0.022], 10, (1.0, 0.55)), "skin", hb)
    finish(f"body__thumb_{side}", tube([(sx * 0.212, 0.84, 0.02), (sx * 0.208, 0.79, 0.034), (sx * 0.214, 0.75, 0.04)], [0.012, 0.01, 0.007], 8), "skin", hb)
    leg_b = [f"leg_{side}_up", f"leg_{side}_lo", f"foot_{side}"]
    leg_path = [(sx * 0.09, 0.97, 0), (sx * 0.094, 0.72, 0.004), (sx * 0.095, 0.5, 0.008), (sx * 0.094, 0.34, 0), (sx * 0.09, 0.1, 0)]
    finish(f"body__leg_{side}", tube(leg_path, [0.088, 0.073, 0.054, 0.053, 0.035]), "skin", lambda p, b=leg_b: smooth_w(p, b, 0.15))

# ---------------------------------------------------------------- GIÀY
for side, sx in (("l", -1.0), ("r", 1.0)):
    fb = f"foot_{side}"
    finish(f"shoes__boot_{side}", ellipsoid((sx * 0.09, 0.05, 0.045), (0.046, 0.05, 0.125)), "shoe", fb)
    finish(f"shoes__cuff_{side}", tube([(sx * 0.09, 0.22, 0), (sx * 0.09, 0.08, 0)], [0.047, 0.044], 14), "shoe", fb)
    finish(f"shoes__sole_{side}", ellipsoid((sx * 0.09, 0.012, 0.05), (0.05, 0.012, 0.135)), "sole", fb)
    finish(f"shoes__toe_{side}", ellipsoid((sx * 0.09, 0.055, 0.14), (0.034, 0.03, 0.03)), "sole", fb)

# ================================================================ MẶT (cứng theo xương đầu)
# mặt cục bộ: mắt ở y ≈ +0.012, mũi y ≈ -0.025, miệng y ≈ -0.065. Bề mặt trước ở z ≈ 0.085-0.097.
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    ex = sx * 0.036
    finish(f"face__sclera_{tag}", ellipsoid(H(ex, 0.012, 0.081), (0.0175, 0.0092, 0.0075)), "white", "head")
    finish(f"face__iris_{tag}", ellipsoid(H(ex, 0.012, 0.0875), (0.0085, 0.0085, 0.004)), "eye", "head")
    finish(f"face__pupil_{tag}", ellipsoid(H(ex, 0.012, 0.0905), (0.0038, 0.0038, 0.002)), "ink", "head")
    finish(f"face__hl_{tag}", ellipsoid(H(ex + sx * 0.003, 0.0155, 0.0925), (0.0018, 0.0018, 0.001)), "white", "head")
    finish(f"face__lid_{tag}", tube([H(ex - sx * 0.019, 0.016, 0.0815), H(ex - sx * 0.008, 0.0225, 0.0885), H(ex + sx * 0.008, 0.023, 0.0885),
                                      H(ex + sx * 0.02, 0.0165, 0.081)], [0.0018, 0.0026, 0.0026, 0.0018], 8), "ink", "head")
    finish(f"face__lash_{tag}", tube([H(ex - sx * 0.018, 0.006, 0.082), H(ex, 0.0035, 0.088), H(ex + sx * 0.018, 0.007, 0.0825)],
                                      [0.0012, 0.0016, 0.0012], 6), "ink", "head")
    finish(f"face__brow_{tag}", tube([H(sx * 0.014, 0.040, 0.0875), H(sx * 0.036, 0.0485, 0.0855), H(sx * 0.06, 0.0455, 0.0745)],
                                      [0.0042, 0.0048, 0.0032], 8, (1.0, 0.8)), "hair", "head")
    finish(f"face__nostril_{tag}", ellipsoid(H(sx * 0.0115, -0.0265, 0.0985), (0.0065, 0.0055, 0.0055)), "skin_dark", "head")
    finish(f"face__cheek_{tag}", ellipsoid(H(sx * 0.054, -0.032, 0.066), (0.02, 0.013, 0.006), rot=(0, sx * 30, 0)), "blush", "head")
finish("face__nose", tube([H(0, 0.012, 0.09), H(0, -0.012, 0.099), H(0, -0.027, 0.107)], [0.0065, 0.0085, 0.0105], 10), "skin", "head")
finish("face__nosetip", ellipsoid(H(0, -0.0275, 0.1045), (0.0105, 0.0085, 0.0085)), "skin", "head")
finish("face__lip_up", tube([H(-0.018, -0.0635, 0.083), H(-0.006, -0.0585, 0.0905), H(0, -0.0605, 0.0915), H(0.006, -0.0585, 0.0905), H(0.018, -0.0635, 0.083)],
                             [0.0028, 0.0036, 0.0034, 0.0036, 0.0028], 8, (1.0, 0.8)), "mouth", "head")
finish("face__lip_lo", tube([H(-0.015, -0.0705, 0.083), H(0, -0.0745, 0.0885), H(0.015, -0.0705, 0.083)], [0.0033, 0.0042, 0.0033], 8, (1.0, 0.85)), "mouth", "head")
finish("face__mouthline", tube([H(-0.019, -0.0655, 0.0825), H(0, -0.0665, 0.089), H(0.019, -0.0655, 0.0825)], [0.0011, 0.0014, 0.0011], 6), "ink", "head")

# ================================================================ TÓC
finish("hair_base__cap", ellipsoid(H(0, 0.015, -0.012), (0.0865, 0.1195, 0.1), seg=40, ring=26), "hair", "head")
# mái rẽ ngôi lệch: mỗi bên một lọn lớn vuốt ra thái dương
for sx, ln in ((-1.0, 1.0), (1.0, 0.85)):
    tag = "l" if sx < 0 else "r"
    finish(f"hair_base__bang_{tag}", tube([H(sx * 0.004, 0.112, 0.03), H(sx * 0.038, 0.098, 0.062), H(sx * 0.07, 0.066, 0.064), H(sx * 0.082, 0.03 * ln, 0.05),
                                           H(sx * 0.084, -0.015 * ln, 0.036)], [0.014, 0.016, 0.014, 0.01, 0.003], 10, (1.0, 0.7)), "hair", "head")
    finish(f"hair_base__bang2_{tag}", tube([H(sx * 0.03, 0.115, 0.02), H(sx * 0.05, 0.1, 0.05), H(sx * 0.068, 0.082, 0.062), H(sx * 0.076, 0.05, 0.058)],
                                            [0.011, 0.012, 0.01, 0.003], 8, (1.0, 0.7)), "hair", "head")
    finish(f"hair_base__sideburn_{tag}", tube([H(sx * 0.082, 0.04, 0.02), H(sx * 0.083, 0.0, 0.025), H(sx * 0.081, -0.04, 0.03)], [0.008, 0.007, 0.002], 6), "hair", "head")

# tóc ngắn: gáy
finish("hair_short__nape", tube([H(0, 0.0, -0.09), H(0, -0.06, -0.085), H(0, -0.1, -0.06)], [0.07, 0.065, 0.045], 14, (1.0, 0.7)), "hair", "head")
# búi tóc
finish("hair_bun__bun", ellipsoid(H(0, 0.145, -0.035), (0.05, 0.044, 0.05)), "hair", "head")
finish("hair_bun__band", tube([H(0, 0.103, -0.03), H(0, 0.118, -0.03)], [0.047, 0.047], 18), "trim", "head")
finish("hair_bun__pin", tube([H(-0.085, 0.145, -0.035), H(0.085, 0.145, -0.035)], [0.004, 0.004], 8), "gold", "head")
finish("hair_bun__nape", tube([H(0, 0.0, -0.09), H(0, -0.05, -0.08)], [0.06, 0.055], 14, (1.0, 0.7)), "hair", "head")

# tóc dài: rủ sau lưng theo chuỗi xương hair1..3 + hai lọn trước vai
def hair_w(p):
    y = p.z
    if y > 1.58:
        return {"head": 1.0}
    if y > 1.4:
        t = (1.58 - y) / 0.18
        return {"hair1": 1.0 - 0.5 * t, "hair2": 0.5 * t}
    if y > 1.2:
        t = (1.4 - y) / 0.2
        return {"hair2": 1.0 - 0.5 * t, "hair3": 0.5 * t}
    return {"hair3": 1.0}


HAIR_PATH = [(0, 1.67, -0.085), (0, 1.55, -0.125), (0, 1.38, -0.138), (0, 1.2, -0.125), (0, 1.02, -0.1)]
finish("hair_long__back", tube(HAIR_PATH, [0.085, 0.092, 0.094, 0.085, 0.05], 18, (1.0, 0.55)), "hair", hair_w)
for k, (x, l) in enumerate([(-0.04, 0.06), (0.0, 0.1), (0.04, 0.06)]):
    finish(f"hair_long__tip{k}", tube([(x, 1.04, -0.1), (x, 1.04 - l * 0.5, -0.1), (x, 1.04 - l, -0.1)], [0.022, 0.014, 0.002], 8), "hair", "hair3")
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    finish(f"hair_long__front_{tag}", tube([H(sx * 0.082, 0.02, 0.02), (sx * 0.09, 1.52, 0.04), (sx * 0.1, 1.38, 0.07), (sx * 0.1, 1.22, 0.075)],
                                            [0.016, 0.02, 0.019, 0.004], 10, (1.0, 0.6)), "hair", hair_w)
finish("hair_long__tie", tube([(0, 1.36, -0.13), (0, 1.33, -0.13)], [0.052, 0.052], 18, (1.0, 0.7)), "trim", hair_w)
# tóc đuôi ngựa
finish("hair_ponytail__tie", tube([H(0, 0.075, -0.1), H(0, 0.095, -0.108)], [0.034, 0.034], 14), "trim", "head")
finish("hair_ponytail__tail", tube([H(0, 0.085, -0.104), (0, 1.7, -0.16), (0, 1.58, -0.22), (0, 1.4, -0.235), (0, 1.22, -0.2), (0, 1.08, -0.16)],
                                    [0.03, 0.04, 0.042, 0.036, 0.022, 0.004], 14, (1.0, 0.8)), "hair", hair_w)
finish("hair_ponytail__nape", tube([H(0, 0.0, -0.09), H(0, -0.05, -0.08)], [0.06, 0.055], 14, (1.0, 0.7)), "hair", "head")
# hai búi hai bên
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    finish(f"hair_twin__bun_{tag}", ellipsoid(H(sx * 0.068, 0.1, -0.012), (0.04, 0.04, 0.04)), "hair", "head")
    finish(f"hair_twin__ring_{tag}", torus(H(sx * 0.066, 0.088, -0.012), 0.028, 0.006, rot=(0, 0, sx * 70)), "trim", "head")
    finish(f"hair_twin__ribbon_{tag}", tube([H(sx * 0.075, 0.085, -0.02), H(sx * 0.098, 0.0, -0.03), H(sx * 0.105, -0.1, -0.035)], [0.011, 0.012, 0.007], 8, (1.0, 0.4)), "trim", "head")
finish("hair_twin__nape", tube([H(0, 0.0, -0.09), H(0, -0.1, -0.075)], [0.062, 0.05], 14, (1.0, 0.7)), "hair", "head")
# tóc dựng ngược ra sau (kiểu hung dữ)
for i in range(7):
    a = math.pi * 2 * i / 7
    bx, bz = math.sin(a) * 0.05, math.cos(a) * 0.05 - 0.02
    finish(f"hair_spike__s{i}", tube([H(bx, 0.11, bz), H(bx * 1.6, 0.17, bz * 1.3 - 0.06), H(bx * 2.4, 0.2, bz * 1.6 - 0.14)], [0.026, 0.02, 0.002], 8), "hair", "head")
finish("hair_spike__nape", tube([H(0, 0.0, -0.09), H(0, -0.07, -0.08)], [0.066, 0.058], 14, (1.0, 0.7)), "hair", "head")

# phụ kiện đầu
finish("head_band__band", tube([H(0, 0.06, -0.004), H(0, 0.082, -0.004)], [0.075, 0.075], 36, (1.0, 1.17)), "trim", "head")
finish("head_crown__base", tube([H(0, 0.118, -0.02), H(0, 0.16, -0.02)], [0.036, 0.026], 20), "trim", "head")
finish("head_crown__pin", tube([H(-0.07, 0.14, -0.02), H(0.07, 0.14, -0.02)], [0.004, 0.004], 8), "trim", "head")
finish("head_crown__gem", ellipsoid(H(0, 0.088, 0.066), (0.008, 0.008, 0.005)), "gem", "head")
finish("head_khan__band", tube([H(0, 0.056, -0.004), H(0, 0.082, -0.004)], [0.076, 0.076], 36, (1.0, 1.17)), "trim", "head")
finish("head_khan__knot", ellipsoid(H(0, 0.065, -0.1), (0.022, 0.018, 0.016)), "trim", "head")
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    finish(f"head_khan__tail_{tag}", tube([H(sx * 0.01, 0.062, -0.105), (sx * 0.025, 1.6, -0.16), (sx * 0.035, 1.42, -0.17), (sx * 0.04, 1.24, -0.15)],
                                         [0.011, 0.013, 0.012, 0.004], 8, (1.0, 0.3)), "trim", hair_w)
finish("head_non__hat", lathe([(0.001, 1.95), (0.04, 1.935), (0.11, 1.9), (0.19, 1.855), (0.265, 1.815), (0.255, 1.806), (0.1, 1.84), (0.001, 1.85)], segs=40), "hat", "head")
finish("head_non__rim", tube([(0, 1.808, 0), (0, 1.82, 0)], [0.262, 0.26], 40), "trim", "head")
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    finish(f"head_non__strap_{tag}", tube([H(sx * 0.082, 0.04, 0.0), H(sx * 0.07, -0.04, 0.04), H(sx * 0.03, -0.1, 0.07)], [0.004, 0.004, 0.004], 6), "trim", "head")

# ================================================================ ÁO
finish("robe_top__chest", lathe([(r + 0.012, y) for r, y in TORSO[2:-1]], sz=TORSO_SZ), "robe", torso_w)
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    finish(f"robe_top__shoulder_{tag}", ellipsoid((sx * 0.194, 1.395, 0), (0.063, 0.07, 0.063)), "robe", lambda p, n=f"arm_{tag}_up": {n: 0.5, "spine": 0.5})
# giao lĩnh: vạt trái đè lên vạt phải, chéo từ cổ trái xuống eo phải
finish("robe_top__lapel_in", tube([(0.04, 1.5, 0.05), (0.03, 1.45, 0.113), (0.015, 1.4, 0.126)], [0.014, 0.014, 0.013], 10, (1.0, 0.3)), "inner", torso_w)
finish("robe_top__lapel_out", tube([(-0.045, 1.5, 0.052), (-0.03, 1.44, 0.117), (0.0, 1.34, 0.13), (0.05, 1.22, 0.123), (0.09, 1.11, 0.117)],
                                    [0.016, 0.017, 0.017, 0.016, 0.015], 10, (1.0, 0.3)), "trim", torso_w)
finish("robe_top__collar_in", tube([(0, 1.485, 0.002), (0, 1.535, 0.004)], [0.06, 0.058], 24), "inner", "neck")
finish("robe_top__collar", tube([(0, 1.475, 0.002), (0, 1.52, 0.004)], [0.068, 0.064], 24), "trim", "neck")
finish("robe_top__sash", lathe([(0.15, 1.03), (0.168, 1.03), (0.168, 1.11), (0.15, 1.11)], sz=0.74, caps=False), "trim", "hips")
finish("robe_top__knot", ellipsoid((0.0, 1.07, 0.12), (0.03, 0.035, 0.02)), "trim", "hips")
finish("robe_top__bow", ellipsoid((0, 1.07, -0.115), (0.022, 0.025, 0.018)), "trim", "hips")
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    finish(f"robe_top__loop_{tag}", ellipsoid((sx * 0.045, 1.075, -0.115), (0.045, 0.025, 0.012), rot=(0, 0, sx * 22)), "trim", "hips")
    finish(f"robe_top__tail_{tag}", tube([(sx * 0.04, 1.06, -0.12), (sx * 0.04, 0.93, -0.12), (sx * 0.04, 0.8, -0.12)], [0.016, 0.016, 0.012], 8, (1.0, 0.3)),
           "trim", lambda p, n=f"tail_{tag}": {n: 1.0} if p.z < 1.0 else {"hips": 1.0})


def skirt_w(p):
    """Váy: phần trên theo hông, phần dưới theo hai đùi; pha trộn mượt theo x để mép váy tách ra khi bước mà không bị rách ở giữa."""
    t = clamp01((1.04 - p.z) / 0.8)
    a = clamp01(0.5 + p.x / 0.2)   # nghiêng về chân phải (+x)
    k = 0.75 * t
    ws = {"hips": 1.0 - k}
    if k * (1 - a) > 0.001:
        ws["leg_l_up"] = k * (1 - a)
    if k * a > 0.001:
        ws["leg_r_up"] = k * a
    return ws


finish("robe_long__skirt", lathe([(0.158, 1.05), (0.172, 0.95), (0.2, 0.75), (0.228, 0.5), (0.25, 0.28), (0.265, 0.1), (0.267, 0.06)], sz=0.95, caps=False), "robe", skirt_w)
finish("robe_long__petti", lathe([(0.262, 0.1), (0.272, 0.09), (0.274, 0.05), (0.262, 0.05)], sz=0.95, caps=False), "inner", skirt_w)
finish("robe_long__hem", lathe([(0.254, 0.22), (0.264, 0.21), (0.267, 0.16), (0.256, 0.16)], sz=0.95, caps=False), "trim", skirt_w)
finish("robe_long__panel", tube([(0, 1.04, 0.158), (0, 0.8, 0.185), (0, 0.5, 0.215), (0, 0.15, 0.255)], [0.045, 0.045, 0.048, 0.05], 10, (1.0, 0.18)), "inner", skirt_w)
for sx in (-1.0, 1.0):
    tag = "l" if sx < 0 else "r"
    finish(f"robe_long__cloud_{tag}", ellipsoid((sx * 0.1, 0.55, 0.19), (0.024, 0.024, 0.006), rot=(0, sx * 28, 0)), "trim", skirt_w)
    finish(f"robe_long__cloud2_{tag}", ellipsoid((sx * 0.13, 0.46, 0.18), (0.017, 0.017, 0.005), rot=(0, sx * 38, 0)), "trim", skirt_w)
finish("robe_mid__skirt", lathe([(0.158, 1.05), (0.172, 0.95), (0.198, 0.78), (0.218, 0.6), (0.225, 0.52)], sz=0.95, caps=False), "robe", skirt_w)
finish("robe_mid__hem", lathe([(0.214, 0.6), (0.226, 0.58), (0.228, 0.5), (0.215, 0.5)], sz=0.95, caps=False), "trim", skirt_w)
finish("robe_mid__panel", tube([(0, 1.04, 0.158), (0, 0.8, 0.18), (0, 0.55, 0.206)], [0.04, 0.04, 0.042], 10, (1.0, 0.18)), "inner", skirt_w)
finish("robe_short__skirt", lathe([(0.158, 1.05), (0.175, 0.95), (0.198, 0.82), (0.206, 0.74)], sz=0.95, caps=False), "robe", skirt_w)
finish("robe_short__hem", lathe([(0.196, 0.8), (0.206, 0.78), (0.208, 0.72), (0.197, 0.72)], sz=0.95, caps=False), "trim", skirt_w)

# quần ôm chân, hộ tay
for side, sx in (("l", -1.0), ("r", 1.0)):
    lb = [f"leg_{side}_up", f"leg_{side}_lo", f"foot_{side}"]
    ab = [f"arm_{side}_up", f"arm_{side}_lo", f"hand_{side}"]
    finish(f"pants__leg_{side}", tube([(sx * 0.09, 0.98, 0), (sx * 0.094, 0.72, 0.004), (sx * 0.095, 0.5, 0.008), (sx * 0.094, 0.34, 0), (sx * 0.09, 0.14, 0)],
                                      [0.094, 0.078, 0.059, 0.058, 0.042], 14), "pants", lambda p, b=lb: smooth_w(p, b, 0.15))
    finish(f"sleeve_guard__bracer_{side}", tube([(sx * 0.226, 1.06, 0), (sx * 0.232, 0.95, 0), (sx * 0.236, 0.865, 0)], [0.045, 0.041, 0.034], 14), "shoe",
           lambda p, b=ab: smooth_w(p, b[:2], 0.12))
    finish(f"sleeve_guard__strap_{side}", tube([(sx * 0.228, 1.03, 0), (sx * 0.23, 1.01, 0)], [0.047, 0.047], 14), "gold", lambda p, b=ab: smooth_w(p, b[:2], 0.12))

# tay áo
for side, sx in (("l", -1.0), ("r", 1.0)):
    ab = [f"arm_{side}_up", f"arm_{side}_lo", f"hand_{side}"]
    wide = [(sx * 0.2, 1.43, 0), (sx * 0.212, 1.27, 0), (sx * 0.222, 1.12, 0), (sx * 0.23, 0.96, 0), (sx * 0.236, 0.84, 0), (sx * 0.238, 0.8, 0)]
    finish(f"sleeve_wide__sleeve_{side}", tube(wide, [0.062, 0.066, 0.078, 0.092, 0.1, 0.1], 20), "robe", lambda p, b=ab: smooth_w(p, b[:2], 0.12))
    finish(f"sleeve_wide__cuff_{side}", tube([(sx * 0.237, 0.835, 0), (sx * 0.238, 0.79, 0)], [0.102, 0.102], 20), "trim", lambda p, b=ab: smooth_w(p, b[:2], 0.12))
    finish(f"sleeve_wide__lining_{side}", tube([(sx * 0.238, 0.792, 0), (sx * 0.238, 0.784, 0)], [0.086, 0.086], 20), "inner", lambda p, b=ab: smooth_w(p, b[:2], 0.12))
    nar = [(sx * 0.2, 1.43, 0), (sx * 0.212, 1.27, 0), (sx * 0.222, 1.12, 0), (sx * 0.23, 0.99, 0), (sx * 0.235, 0.9, 0)]
    finish(f"sleeve_narrow__sleeve_{side}", tube(nar, [0.059, 0.053, 0.047, 0.043, 0.04], 16), "robe", lambda p, b=ab: smooth_w(p, b[:2], 0.12))
    finish(f"sleeve_narrow__cuff_{side}", tube([(sx * 0.234, 0.915, 0), (sx * 0.236, 0.885, 0)], [0.043, 0.043], 16), "trim", lambda p, b=ab: smooth_w(p, b[:2], 0.12))


# ================================================================ ĐỒ SAU LƯNG
def cape_w(p):
    t = clamp01((1.38 - p.z) / 0.83)
    return {"cape1": 1.0 - t, "cape2": t} if 0.01 < t < 0.99 else ({"cape1": 1.0} if t <= 0.01 else {"cape2": 1.0})


finish("back_cape__lining", slab((0, 0.93, -0.13), (0.38, 0.9, 0.012), cuts=8), "trim", cape_w)
finish("back_cape__outer", slab((0, 0.93, -0.142), (0.35, 0.87, 0.012), cuts=8), "robe", cape_w)
# kiếm đeo chéo sau lưng, chuôi nhô qua vai phải
SW_ROT = (0, 0, -36)
sd = Vector((math.sin(math.radians(36)), math.cos(math.radians(36))))   # hướng lưỡi kiếm (x, y)
sc = Vector((0.0, 1.1))
sz_ = -0.135


def sword_at(t):
    return (sc.x + sd.x * t, sc.y + sd.y * t, sz_)


finish("back_sword__blade", slab(sword_at(0.0), (0.034, 0.8, 0.012), rot=SW_ROT), "steel", "spine")
finish("back_sword__guard", slab(sword_at(0.41), (0.1, 0.018, 0.02), rot=SW_ROT), "gold", "spine")
finish("back_sword__grip", slab(sword_at(0.5), (0.024, 0.14, 0.024), rot=SW_ROT), "trim", "spine")
finish("back_sword__pommel", ellipsoid(sword_at(0.58), (0.016, 0.016, 0.016)), "gold", "spine")

# ================================================================ PHỤ KIỆN HÔNG (mỗi bên 1 bộ; Godot chọn bên nào hiện)
for side, sx in (("l", -1.0), ("r", 1.0)):
    pb = f"pend_{side}"
    x = sx * 0.19
    finish(f"acc_pouch_{side}__bag", ellipsoid((x, 0.94, 0.075), (0.04, 0.045, 0.026)), "skin_dark", pb)
    finish(f"acc_pouch_{side}__flap", ellipsoid((x, 0.975, 0.078), (0.043, 0.02, 0.029)), "shoe", pb)
    finish(f"acc_jade_{side}__rope", tube([(x, 1.06, 0.075), (x, 0.95, 0.075)], [0.003, 0.003], 6), "trim", pb)
    finish(f"acc_jade_{side}__ring", torus((x, 0.92, 0.075), 0.02, 0.008, rot=(90, 0, 0)), "jade", pb)
    for k, dx in enumerate((-0.009, 0, 0.009)):
        finish(f"acc_jade_{side}__tassel{k}", tube([(x + dx, 0.9, 0.075), (x + dx, 0.78, 0.075)], [0.005, 0.003], 6), "trim", pb)
    finish(f"acc_bell_{side}__rope", tube([(x, 1.06, 0.075), (x, 0.97, 0.075)], [0.003, 0.003], 6), "trim", pb)
    finish(f"acc_bell_{side}__bell", ellipsoid((x, 0.94, 0.075), (0.022, 0.022, 0.022)), "gold", pb)
    finish(f"acc_gourd_{side}__rope", tube([(x, 1.06, 0.075), (x, 0.98, 0.075)], [0.003, 0.003], 6), "trim", pb)
    finish(f"acc_gourd_{side}__top", ellipsoid((x, 0.955, 0.075), (0.02, 0.022, 0.02)), "gourd", pb)
    finish(f"acc_gourd_{side}__bottom", ellipsoid((x, 0.9, 0.075), (0.034, 0.04, 0.034)), "gourd", pb)
    finish(f"acc_gourd_{side}__cork", ellipsoid((x, 0.98, 0.075), (0.008, 0.009, 0.008)), "shoe", pb)
    finish(f"acc_gourd_{side}__tassel", tube([(x, 0.86, 0.075), (x, 0.78, 0.075)], [0.007, 0.004], 6), "trim", pb)
    finish(f"acc_flute_{side}__flute", tube([(sx * 0.05, 1.1, 0.125), (sx * 0.2, 0.94, 0.095)], [0.01, 0.01], 8), "bamboo", "hips")
    finish(f"acc_flute_{side}__tassel", tube([(sx * 0.195, 0.945, 0.095), (sx * 0.2, 0.86, 0.095)], [0.006, 0.004], 6), "trim", pb)

# ================================================================ ANIMATION
FPS = 30
bpy.context.scene.render.fps = FPS
ARM.animation_data_create()
rest_q = {n: ARM.data.bones[n].matrix_local.to_quaternion() for n in BONES}
rest_m = {n: ARM.data.bones[n].matrix_local.to_3x3() for n in BONES}
for pb in ARM.pose.bones:
    pb.rotation_mode = "QUATERNION"


def world_axis_rot(bone, axis, deg):
    """Quaternion cục bộ của xương tương ứng xoay `deg` độ quanh trục thế giới (kiểu Godot: 'x', 'y', 'z')."""
    ax = {"x": Vector((1, 0, 0)), "y": Vector((0, 0, 1)), "z": Vector((0, -1, 0))}[axis]
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
        "spine": [("x", -0.8 * s)], "head": [("x", 0.6 * s), ("z", 0.8 * math.sin(t * 0.5))],
        "arm_l_up": [("z", -3 + 0.8 * s)], "arm_r_up": [("z", 3 - 0.8 * s)],
        "arm_l_lo": [("x", -5)], "arm_r_lo": [("x", -5)],
        "hair1": [("x", 1.5 + s)], "hair2": [("x", 2 + 1.5 * math.sin(t - 0.6))], "hair3": [("x", 3 + 2 * math.sin(t - 1.2))],
        "cape1": [("x", 2 + s)], "cape2": [("x", 3 + 2 * math.sin(t - 0.8))],
        "tail_l": [("x", 4 + 2 * math.sin(t - 0.4))], "tail_r": [("x", 4 + 2 * math.sin(t - 0.7))],
        "pend_l": [("x", 1.5 * math.sin(t))], "pend_r": [("x", 1.5 * math.sin(t - 0.5))],
    }, {"hips": (0, 0.003 * s, 0)})


def walk(f):
    t = f / 30.0 * 2 * math.pi
    s = math.sin(t)
    bob = abs(math.sin(t)) * 0.03
    knee_l = max(0.0, math.sin(t + math.pi * 0.5)) * 42
    knee_r = max(0.0, math.sin(t - math.pi * 0.5)) * 42
    return ({
        "leg_l_up": [("x", -28 * s)], "leg_r_up": [("x", 28 * s)],
        "leg_l_lo": [("x", knee_l)], "leg_r_lo": [("x", knee_r)],
        "foot_l": [("x", -6 * s)], "foot_r": [("x", 6 * s)],
        "arm_l_up": [("x", 24 * s), ("z", -3)], "arm_r_up": [("x", -24 * s), ("z", 3)],
        "arm_l_lo": [("x", -14 - 8 * max(0.0, s))], "arm_r_lo": [("x", -14 - 8 * max(0.0, -s))],
        "spine": [("y", 5 * s), ("x", -3)], "hips": [("y", -4 * s)], "head": [("y", -3 * s), ("x", 2)],
        "hair1": [("x", 5 + 2 * math.sin(2 * t))], "hair2": [("x", 7 + 3 * math.sin(2 * t - 0.8))], "hair3": [("x", 9 + 4 * math.sin(2 * t - 1.6))],
        "cape1": [("x", 6 + 2 * math.sin(2 * t - 0.4))], "cape2": [("x", 10 + 4 * math.sin(2 * t - 1.1))],
        "tail_l": [("x", 16 + 6 * math.sin(2 * t))], "tail_r": [("x", 16 + 6 * math.sin(2 * t - 0.5))],
        "pend_l": [("x", -8 + 7 * math.sin(2 * t))], "pend_r": [("x", -8 + 7 * math.sin(2 * t - 0.6))],
    }, {"hips": (0, bob, 0)})


def attack(f):
    u = f / 18.0
    if u < 0.3:
        k = u / 0.3
        up, lo, tw = -160 * k, -45 * k, -16 * k
    elif u < 0.6:
        k = (u - 0.3) / 0.3
        up, lo, tw = -160 + 215 * k, -45 + 40 * k, -16 + 32 * k
    else:
        k = (u - 0.6) / 0.4
        up, lo, tw = 55 * (1 - k), -5 * (1 - k), 16 * (1 - k)
    return ({
        "arm_r_up": [("x", up), ("z", 8)], "arm_r_lo": [("x", lo)], "spine": [("y", tw), ("x", -4 * math.sin(u * math.pi))],
        "arm_l_up": [("z", -10), ("x", 8 * math.sin(u * math.pi))], "head": [("y", -tw * 0.4)],
        "hair1": [("x", 3)], "hair2": [("x", 5 + 5 * math.sin(u * math.pi))], "hair3": [("x", 6 + 7 * math.sin(u * math.pi))],
        "cape2": [("x", 6 + 8 * math.sin(u * math.pi))],
    }, {})


make_action("idle_loop", list(range(0, 61, 5)), idle)
make_action("walk_loop", list(range(0, 31, 2)), walk)
make_action("attack", list(range(0, 19, 2)), attack)
pose(0, *idle(0))   # đưa về tư thế nghỉ (không giữ khoá)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, 60

# ================================================================ XUẤT
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", export_yup=True, export_apply=False, export_skins=True,
    export_animations=True, export_animation_mode="NLA_TRACKS", export_materials="EXPORT",
    export_image_format="NONE", export_cameras=False, export_lights=False, export_extras=False,
)
print("lật pháp tuyến:", len(FLIPPED), FLIPPED[:8])
print("OK ->", OUT, "| objects:", len([o for o in bpy.data.objects if o.type == "MESH"]))
