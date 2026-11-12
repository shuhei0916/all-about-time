"""ゲームの ATM(src/world/atm.tscn)の見た目のモデルを作り、glb に書き出す。

使い方(プロジェクトのフォルダで):
    blender -b --factory-startup --python tools/blender/make_atm.py
    blender -b --factory-startup --python tools/blender/make_atm.py -- --render <絵の出力フォルダ>
書き出し先は assets/models/atm/atm.glb。--render を付けると、確認用の絵(正面、操作盤の寄り)も描く。
絵は Godot に取り込まれないよう、assets の外に出す。
Blender は Z が上。正面は -Y を向ける(glTF に書き出すと Godot の +Z が正面になる)。
大きさはゲームの当たり判定に合わせて 幅0.8m × 奥行0.6m × 高さ1.8m、原点は床の中心。
"""
import math
import os
import sys

import bpy

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GLB_PATH = os.path.join(PROJECT, "assets", "models", "atm", "atm.glb")
render_dir = ARGS[ARGS.index("--render") + 1] if "--render" in ARGS else None

# 最初のシーンの物を消す
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()


# --- 材質 ---
def material(name, color, metallic=0.0, roughness=0.5, emission=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


M_BODY = material("Body", (0.62, 0.65, 0.68), metallic=0.6, roughness=0.35)
M_DARK = material("Dark", (0.06, 0.065, 0.075), metallic=0.2, roughness=0.45)
M_TRIM = material("Trim", (0.03, 0.32, 0.38), metallic=0.3, roughness=0.4)
M_SCREEN = material("Screen", (0.05, 0.2, 0.35), roughness=0.15,
                    emission=(0.25, 0.65, 1.0), strength=2.0)
M_SIGN = material("Sign", (0.9, 0.95, 1.0), roughness=0.3,
                  emission=(0.75, 0.95, 1.0), strength=3.0)
M_KEY = material("Key", (0.75, 0.76, 0.78), metallic=0.8, roughness=0.25)
M_RED = material("KeyRed", (0.7, 0.08, 0.06), roughness=0.4)
M_YELLOW = material("KeyYellow", (0.85, 0.65, 0.05), roughness=0.4)
M_GREEN = material("KeyGreen", (0.08, 0.55, 0.15), roughness=0.4)
M_LED = material("Led", (0.1, 0.9, 0.3), emission=(0.1, 1.0, 0.3), strength=4.0)


def box(name, size, center, mat, rot_x=0.0, bevel=0.0):
    """size と center は (x, y, z)。rot_x は X 軸まわりの傾き(度)。"""
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.rotation_euler = (math.radians(rot_x), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    return obj


def cut(target, cutter):
    """target から cutter の形をくり抜き、cutter は消す。"""
    mod = target.modifiers.new("Cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    # 面取りより先にくり抜く
    target.modifiers.move(len(target.modifiers) - 1, 0)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier="Cut")
    bpy.data.objects.remove(cutter)


def text(name, body, center, size, mat, depth=0.004):
    bpy.ops.object.text_add(location=center, rotation=(math.radians(90), 0, 0))
    obj = bpy.context.active_object
    obj.name = name
    obj.data.body = body
    obj.data.size = size
    obj.data.extrude = depth
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    obj.data.materials.append(mat)
    bpy.ops.object.convert(target="MESH")
    return obj


FRONT = -0.3  # 正面の面の y

# --- 台座と本体 ---
box("Plinth", (0.84, 0.64, 0.06), (0, 0, 0.03), M_DARK, bevel=0.01)
body = box("Body", (0.8, 0.6, 1.52), (0, 0, 0.06 + 0.76), M_BODY, bevel=0.012)

# 画面と操作盤のくぼみ(上の本体が庇になる)
BAY_BOTTOM, BAY_TOP, BAY_BACK = 0.9, 1.46, -0.1
bay = box("BayCutter", (0.62, 0.4, BAY_TOP - BAY_BOTTOM),
          (0, BAY_BACK - 0.2, (BAY_BOTTOM + BAY_TOP) / 2), M_DARK)
cut(body, bay)

# くぼみの内側を暗くする板
box("BayLining", (0.62, 0.01, BAY_TOP - BAY_BOTTOM),
    (0, BAY_BACK - 0.004, (BAY_BOTTOM + BAY_TOP) / 2), M_DARK)

# 画面(少し上を向く)
box("ScreenBezel", (0.5, 0.02, 0.34), (0, BAY_BACK - 0.02, 1.25), M_DARK, rot_x=-8, bevel=0.005)
box("Screen", (0.44, 0.01, 0.28), (0, BAY_BACK - 0.033, 1.25), M_SCREEN, rot_x=-8)

# 覗き見よけの袖(くぼみの両脇に張り出す)
for side in (-1, 1):
    box(f"Wing{'L' if side < 0 else 'R'}", (0.03, 0.1, BAY_TOP - BAY_BOTTOM + 0.04),
        (side * 0.325, FRONT - 0.03, (BAY_BOTTOM + BAY_TOP) / 2), M_TRIM, bevel=0.006)

# 操作盤(手前へ傾いた棚)
SHELF_TILT = 18
shelf_center = (0, FRONT - 0.02, BAY_BOTTOM + 0.03)
box("Console", (0.62, 0.26, 0.05), shelf_center, M_DARK, rot_x=SHELF_TILT, bevel=0.006)


def on_shelf(x, y_along, height):
    """棚の上面の点。y_along は棚の奥行き方向(奥が +)、height は上面からの高さ。"""
    t = math.radians(SHELF_TILT)
    cy, cz = shelf_center[1], shelf_center[2]
    up = 0.025 + height
    return (x, cy + y_along * math.cos(t) - up * math.sin(t),
            cz + y_along * math.sin(t) + up * math.cos(t))


# テンキー 3列×4段
KEY = 0.034
for row in range(4):
    for col in range(3):
        box(f"Key{row}{col}", (KEY, KEY, 0.012),
            on_shelf(-0.17 + col * 0.042, 0.07 - row * 0.042, 0.006), M_KEY,
            rot_x=SHELF_TILT, bevel=0.003)
# 取消・訂正・確認
for i, mat in enumerate((M_RED, M_YELLOW, M_GREEN)):
    box(f"Func{i}", (0.06, KEY, 0.012), on_shelf(-0.02, 0.07 - i * 0.042, 0.006), mat,
        rot_x=SHELF_TILT, bevel=0.003)

# カードの差し込み口と光
box("CardReader", (0.12, 0.09, 0.03), on_shelf(0.18, 0.04, 0.015), M_TRIM,
    rot_x=SHELF_TILT, bevel=0.006)
box("CardSlot", (0.09, 0.012, 0.006), on_shelf(0.18, 0.0, 0.031), M_DARK, rot_x=SHELF_TILT)
box("CardLed", (0.012, 0.012, 0.004), on_shelf(0.18, 0.07, 0.031), M_LED, rot_x=SHELF_TILT)

# 紙幣の出し入れ口(くぼみの下の正面)
box("CashBezel", (0.44, 0.03, 0.09), (0, FRONT - 0.01, 0.74), M_TRIM, bevel=0.008)
box("CashSlot", (0.36, 0.02, 0.025), (0, FRONT - 0.021, 0.74), M_DARK)
text("CashLabel", "CASH", (0, FRONT - 0.026, 0.67), 0.035, M_DARK, depth=0.001)

# 明細の出口
box("ReceiptSlot", (0.1, 0.02, 0.012), (0.24, FRONT - 0.008, 0.82), M_DARK)

# 下の金庫の扉(線と鍵)
box("SafeDoor", (0.66, 0.01, 0.5), (0, FRONT - 0.003, 0.36), M_BODY, bevel=0.004)
box("SafeSeamTop", (0.66, 0.012, 0.006), (0, FRONT - 0.002, 0.61), M_DARK)
box("SafeSeamBottom", (0.66, 0.012, 0.006), (0, FRONT - 0.002, 0.11), M_DARK)
box("SafeLock", (0.04, 0.02, 0.06), (0.27, FRONT - 0.012, 0.4), M_DARK, bevel=0.005)

# 帯の色(本体の両側面と正面の縁)
for side in (-1, 1):
    box(f"SideStripe{'L' if side < 0 else 'R'}", (0.006, 0.6, 0.05),
        (side * 0.401, 0, 1.5), M_TRIM)

# --- 上の看板 ---
box("SignBox", (0.8, 0.6, 0.22), (0, 0, 1.58 + 0.11), M_TRIM, bevel=0.01)
box("SignPanel", (0.72, 0.01, 0.15), (0, FRONT - 0.002, 1.69), M_SIGN)
text("SignText", "ATM", (0, FRONT - 0.012, 1.69), 0.12, M_TRIM, depth=0.006)

# 平らな面が滑らかに見えるよう、法線は角度で分ける
for obj in bpy.data.objects:
    if obj.type == "MESH":
        bpy.context.view_layer.objects.active = obj
        try:
            bpy.ops.object.shade_auto_smooth(angle=math.radians(30))
        except Exception:
            pass

# --- 書き出し ---
os.makedirs(os.path.dirname(GLB_PATH), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=GLB_PATH, export_format="GLB", export_apply=True)
print("EXPORTED", GLB_PATH)
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
scene.render.resolution_y = 1100
scene.render.film_transparent = False

world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.18, 0.2, 0.24, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6

bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
bpy.context.active_object.data.materials.append(material("Floor", (0.25, 0.25, 0.27), roughness=0.8))

bpy.ops.object.light_add(type="AREA", location=(-1.5, -2.5, 3.0))
key = bpy.context.active_object
key.data.energy = 500
key.data.size = 2.5
key.rotation_euler = (math.radians(50), 0, math.radians(-30))
bpy.ops.object.light_add(type="SUN", location=(2, 2, 4))
bpy.context.active_object.data.energy = 1.5
bpy.context.active_object.rotation_euler = (math.radians(40), math.radians(20), math.radians(140))

bpy.ops.object.camera_add()
cam = bpy.context.active_object
scene.camera = cam
cam.data.lens = 50


def shoot(name, location, target):
    cam.location = location
    direction = (target[0] - location[0], target[1] - location[1], target[2] - location[2])
    from mathutils import Vector
    cam.rotation_euler = Vector(direction).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(render_dir, name)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)


shoot("atm_front.png", (1.3, -3.2, 1.6), (0, 0, 0.95))
shoot("atm_close.png", (0.35, -1.2, 1.45), (0, -0.2, 1.05))
