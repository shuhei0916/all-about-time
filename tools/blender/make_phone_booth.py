"""ゲームの電話ボックス(src/world/phone_booth.tscn)の見た目のモデルを作り、glb に書き出す。

使い方(プロジェクトのフォルダで):
    blender -b --factory-startup --python tools/blender/make_phone_booth.py
    blender -b --factory-startup --python tools/blender/make_phone_booth.py -- --render <絵の出力フォルダ>
書き出し先は assets/models/phone_booth/ の2つ。
    phone_booth_shell.glb  外側(柱、ガラス、腰板、屋根)。動かない
    phone_booth_car.glb    内部(床、電話、地図の枠、それらを支える支柱)。乗った人ごと沈み、上から降りてくる
--render を付けると、確認用の絵(外から、中から)も描く。絵は Godot に取り込まれないよう、assets の外に出す。

Blender は Z が上。入口は -Y を向ける(glTF に書き出すと Godot の +Z が入口になる)。
大きさはゲームの当たり判定に合わせる。外側は 1.2m 四方 × 高さ 2.6m、内側は 1.0m 四方、
入口は幅 0.8m × 高さ 2.2m。原点は床の中心。
内部の床の上面は高さ 0。電話は奥の壁(+Y)の中ほど、地図は左の壁(-X)に掛ける。
電話の画面の文字、地図の絵、箱の番号は Godot の側で描く(Label3D と板)。
"""
import math
import os
import sys

import bpy

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(PROJECT, "assets", "models", "phone_booth")
render_dir = ARGS[ARGS.index("--render") + 1] if "--render" in ARGS else None

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()


# --- 材質 ---
def material(name, color, metallic=0.0, roughness=0.5, emission=None, strength=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            mat.surface_render_method = "BLENDED"
        except AttributeError:
            mat.blend_method = "BLEND"
    return mat


M_BODY = material("Body", (0.07, 0.28, 0.27), metallic=0.5, roughness=0.4)
M_BODY_DARK = material("BodyDark", (0.04, 0.14, 0.14), metallic=0.5, roughness=0.5)
M_BRASS = material("Brass", (0.75, 0.55, 0.22), metallic=0.9, roughness=0.3)
M_GLASS = material("Glass", (0.7, 0.85, 0.85), roughness=0.05, alpha=0.1)
M_GLOW = material("Glow", (0.6, 1.0, 0.95), emission=(0.45, 1.0, 0.9), strength=4.0)
M_HEADER = material("Header", (0.03, 0.05, 0.05), roughness=0.4)
M_FLOOR = material("Floor", (0.12, 0.12, 0.13), roughness=0.9)
M_PHONE = material("Phone", (0.1, 0.1, 0.11), metallic=0.4, roughness=0.35)
M_KEY = material("Key", (0.7, 0.7, 0.72), metallic=0.8, roughness=0.25)
M_SCREEN = material("PhoneScreen", (0.02, 0.06, 0.03), roughness=0.2)
M_FRAME = material("MapFrame", (0.2, 0.2, 0.22), metallic=0.3, roughness=0.5)


def box(name, size, center, mat, bevel=0.0, rot=(0, 0, 0)):
    """size と center は (x, y, z)。rot は各軸の回転(度)。"""
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.rotation_euler = tuple(math.radians(r) for r in rot)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    return obj


def cylinder(name, radius, depth, center, mat, rot=(0, 0, 0), vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=center, vertices=vertices,
                                        rotation=tuple(math.radians(r) for r in rot))
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


# ============ 外側 ============
shell = []
OUT = 0.6      # 外側の半分
IN = 0.5       # 内側の半分
POST = 0.1     # 柱の太さ
HEIGHT = 2.6
KICK = 0.4     # 腰板の高さ
GLASS_TOP = 2.25
ROOF_BOTTOM = 2.32

# 四隅の柱
for sx in (-1, 1):
    for sy in (-1, 1):
        shell.append(box(f"Post{sx}{sy}", (POST, POST, ROOF_BOTTOM), (sx * (OUT - POST / 2), sy * (OUT - POST / 2), ROOF_BOTTOM / 2),
                         M_BODY, bevel=0.01))

# 奥と左右の壁: 腰板、ガラス、真鍮の横桟
walls = [  # (名前, 中心の x, y, 壁の向き: 'x' は X に沿う壁)
    ("Back", 0, OUT - 0.03, "x"),
    ("Left", -(OUT - 0.03), 0, "y"),
    ("Right", OUT - 0.03, 0, "y"),
]
span = 2 * (OUT - POST)
for name, cx, cy, along in walls:
    def size(width, thick, height):
        return (width, thick, height) if along == "x" else (thick, width, height)
    shell.append(box(f"{name}Kick", size(span, 0.05, KICK), (cx, cy, KICK / 2), M_BODY_DARK, bevel=0.005))
    # 腰板の縦の溝
    for i in range(1, 6):
        offset = -span / 2 + span * i / 6
        pos = (cx + offset, cy - 0.028 * (1 if cy > 0 else -1), KICK / 2) if along == "x" else \
              (cx - 0.028 * (1 if cx > 0 else -1), cy + offset, KICK / 2)
        shell.append(box(f"{name}Rib{i}", size(0.012, 0.01, KICK - 0.08), pos, M_BODY))
    shell.append(box(f"{name}Glass", size(span, 0.01, GLASS_TOP - KICK), (cx, cy, (KICK + GLASS_TOP) / 2), M_GLASS))
    for z in (KICK, GLASS_TOP, (KICK + GLASS_TOP) / 2 + 0.25):
        shell.append(box(f"{name}Rail{z:.2f}", size(span, 0.04, 0.035), (cx, cy, z), M_BRASS, bevel=0.004))

# 入口の上の看板(番号は Godot の Label3D で、この看板の手前に描く)
DOOR_TOP = 2.2
shell.append(box("Header", (2 * OUT, 0.06, ROOF_BOTTOM - DOOR_TOP), (0, -(OUT - 0.03), (DOOR_TOP + ROOF_BOTTOM) / 2), M_HEADER))
shell.append(box("HeaderTrim", (2 * OUT, 0.07, 0.025), (0, -(OUT - 0.03), DOOR_TOP), M_BRASS))
# 入口の両脇の細い框
for sx in (-1, 1):
    shell.append(box(f"Jamb{sx}", (0.02, 0.07, DOOR_TOP), (sx * (OUT - POST - 0.01), -(OUT - 0.03), DOOR_TOP / 2), M_BRASS))

# 屋根: 少し張り出した平らな屋根と、縁を一周する光る帯、頂の小さな光る箱
shell.append(box("RoofBase", (2 * OUT + 0.08, 2 * OUT + 0.08, 0.08), (0, 0, ROOF_BOTTOM + 0.04), M_BODY, bevel=0.01))
shell.append(box("RoofGlow", (2 * OUT + 0.06, 2 * OUT + 0.06, 0.06), (0, 0, ROOF_BOTTOM + 0.11), M_GLOW))
shell.append(box("RoofCap", (2 * OUT + 0.1, 2 * OUT + 0.1, 0.06), (0, 0, ROOF_BOTTOM + 0.17), M_BODY_DARK, bevel=0.012))
shell.append(box("Beacon", (0.22, 0.22, 0.1), (0, 0, ROOF_BOTTOM + 0.25), M_GLOW, bevel=0.02))
shell.append(box("BeaconCap", (0.26, 0.26, 0.03), (0, 0, ROOF_BOTTOM + 0.315), M_BRASS, bevel=0.008))

# ============ 内部 ============
car = []
car.append(box("CarFloor", (2 * IN, 2 * IN, 0.06), (0, 0, -0.03), M_FLOOR, bevel=0.005))
car.append(box("CarFloorTrim", (2 * IN + 0.01, 2 * IN + 0.01, 0.015), (0, 0, -0.0075), M_BRASS))
# 床の滑り止めの筋
for i in range(-4, 5):
    car.append(box(f"Tread{i}", (2 * IN - 0.1, 0.02, 0.006), (0, i * 0.1, 0.003), M_PHONE))

# 電話(Godot では (0, 1.3, -0.42) を中心に 0.26 × 0.42 × 0.12。ここでは +Y が奥)
PX, PY, PZ = 0.0, 0.42, 1.3
car.append(box("PhoneBody", (0.26, 0.12, 0.42), (PX, PY, PZ), M_PHONE, bevel=0.015))
car.append(box("PhoneScreen", (0.18, 0.005, 0.07), (PX, PY - 0.062, PZ + 0.12), M_SCREEN))
for row in range(4):
    for col in range(3):
        car.append(box(f"PhoneKey{row}{col}", (0.04, 0.012, 0.03),
                       (PX - 0.05 + col * 0.05, PY - 0.064, PZ + 0.03 - row * 0.042), M_KEY, bevel=0.003))
# 受話器と掛け金(左側)
car.append(box("Cradle", (0.05, 0.05, 0.08), (PX - 0.155, PY - 0.03, PZ + 0.12), M_BRASS, bevel=0.006))
car.append(cylinder("Handset", 0.022, 0.24, (PX - 0.17, PY - 0.07, PZ), M_PHONE))
for dz in (-0.12, 0.12):
    car.append(box(f"HandsetEnd{dz:+.2f}", (0.05, 0.06, 0.05), (PX - 0.17, PY - 0.075, PZ + dz), M_PHONE, bevel=0.01))
# 電話を支える支柱(壁のない内部でも宙に浮かないように)
car.append(box("PhonePost", (0.06, 0.04, PZ - 0.21), (PX, PY + 0.04, (PZ - 0.21) / 2), M_BRASS, bevel=0.005))

# 地図の枠(Godot の MapBoard の板は x=-0.45 に貼る。枠はその後ろ)
MX, MZ = -0.47, 1.45
car.append(box("MapFrame", (0.03, 0.86, 0.86), (MX, 0, MZ), M_FRAME, bevel=0.006))
car.append(box("MapFrameTrim", (0.035, 0.9, 0.02), (MX, 0, MZ + 0.44), M_BRASS))
car.append(box("MapFrameTrimLow", (0.035, 0.9, 0.02), (MX, 0, MZ - 0.44), M_BRASS))
car.append(box("MapPost", (0.04, 0.06, MZ - 0.43), (MX - 0.005, 0, (MZ - 0.43) / 2), M_BRASS, bevel=0.005))

# 平らな面が滑らかに見えるよう、法線は角度で分ける
for obj in bpy.data.objects:
    if obj.type == "MESH":
        bpy.context.view_layer.objects.active = obj
        try:
            bpy.ops.object.shade_auto_smooth(angle=math.radians(30))
        except Exception:
            pass


# --- 書き出し ---
def export(objects, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    path = os.path.join(OUT_DIR, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, use_selection=True)
    print("EXPORTED", path)


os.makedirs(OUT_DIR, exist_ok=True)
export(shell, "phone_booth_shell.glb")
export(car, "phone_booth_car.glb")

if render_dir is None:
    sys.exit(0)
os.makedirs(render_dir, exist_ok=True)

# --- 確認用の絵 ---
scene = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        continue
scene.render.resolution_x = 900
scene.render.resolution_y = 1200
world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.12, 0.14, 0.2, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, -0.06))
bpy.context.active_object.data.materials.append(material("Ground", (0.35, 0.35, 0.36), roughness=0.8))
bpy.ops.object.light_add(type="AREA", location=(-2.0, -3.0, 3.5))
key = bpy.context.active_object
key.data.energy = 600
key.data.size = 3
key.rotation_euler = (math.radians(50), 0, math.radians(-30))
bpy.ops.object.light_add(type="POINT", location=(0, 0, 2.2))
bpy.context.active_object.data.energy = 40
bpy.ops.object.camera_add()
cam = bpy.context.active_object
scene.camera = cam


def shoot(name, location, target, lens):
    cam.location = location
    direction = [t - l for t, l in zip(target, location)]
    cam.rotation_euler = (math.atan2(math.hypot(direction[0], direction[1]), -direction[2]), 0,
                          math.atan2(direction[1], direction[0]) - math.pi / 2)
    cam.data.lens = lens
    scene.render.filepath = os.path.join(render_dir, name)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)


shoot("front.png", (1.6, -3.4, 1.7), (0, 0, 1.25), 35)
shoot("inside.png", (0.1, -0.35, 1.6), (-0.2, 0.42, 1.3), 18)
