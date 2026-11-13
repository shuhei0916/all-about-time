"""Quaternius の Train Pack(CC0)から、列車の車両を glb に書き出す。

使い方(プロジェクトのフォルダで):
    blender -b --factory-startup --python tools/blender/export_train.py -- --pack <パックのフォルダ>
    blender -b --factory-startup --python tools/blender/export_train.py -- --pack <パックのフォルダ> --render <絵の出力フォルダ>
<パックのフォルダ> は zip を展開した "Train Pack - April 2019"(中に Blends がある所)。
パックは Godot と Git に取り込まず、使う車両だけを assets/models/train/ に書き出す。
--render を付けると、確認用の絵(先頭車を斜め前から)も描く。絵は assets の外に出す。

向き: 車両の前(先頭車の運転台の側)を Blender の +Y に向ける。glTF に書き出すと Godot の -Z が前になる。
大きさ: パックの車両は幅 2.15m、高さ 2.7m と実物より小さいので、SCALE 倍する。原点は床の中心。
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(PROJECT, "assets", "models", "train")
pack_dir = ARGS[ARGS.index("--pack") + 1]
render_dir = ARGS[ARGS.index("--render") + 1] if "--render" in ARGS else None

SCALE = 1.4
## パックの車両は X の向きに長い。先頭車の運転台は -X の側にある。
NOSE_AT_NEGATIVE_X = True
## 書き出す車両: パックの .blend の名前 → 書き出す glb の名前
CARS = {
    "CargoTrain_Front": "train_front",
    "CargoTrain_Wagon": "train_wagon",
}

## 光る材質(前照灯など)
LIGHTS = {"Lights"}


def simplify_materials():
    """パックの材質は出力ノードが2つあり、glTF の書き出しがつながっていない方を拾って色が抜ける。
    どの材質も Principled BSDF 1つだけに組み直す。色は材質の表示色(diffuse_color)を使う。"""
    for mat in bpy.data.materials:
        color = tuple(mat.diffuse_color)
        nodes = mat.node_tree.nodes
        nodes.clear()
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        out = nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.6
        if mat.name in LIGHTS:
            bsdf.inputs["Emission Color"].default_value = color
            bsdf.inputs["Emission Strength"].default_value = 3.0


def export_car(blend_name, glb_name):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(pack_dir, "Blends", blend_name + ".blend"))
    simplify_materials()
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    # 原点を軸に回して大きくし、回転と拡大を形に焼き込む
    turn = -math.pi / 2 if NOSE_AT_NEGATIVE_X else math.pi / 2
    pivot = bpy.data.objects.new("Pivot", None)
    bpy.context.scene.collection.objects.link(pivot)
    for o in meshes:
        o.parent = pivot
    pivot.rotation_euler = (0, 0, turn)
    pivot.scale = (SCALE, SCALE, SCALE)
    bpy.context.view_layer.update()
    for o in meshes:
        world = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = world
    bpy.data.objects.remove(pivot)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, glb_name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True)
    corners = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    size = [max(v[i] for v in corners) - min(v[i] for v in corners) for i in range(3)]
    print("EXPORTED", path, "幅 %.2f 長さ %.2f 高さ %.2f" % tuple(size))


for blend_name, glb_name in CARS.items():
    export_car(blend_name, glb_name)

if render_dir is None:
    sys.exit(0)

# 確認用の絵: 書き出した先頭車と客車2両を並べ、斜め前から撮る
bpy.ops.wm.read_factory_settings(use_empty=True)
for i, name in enumerate(["train_front", "train_wagon", "train_wagon"]):
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUT_DIR, name + ".glb"))
    for o in bpy.context.selected_objects:
        if o.parent is None:
            o.location.y -= i * 15.0
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.6, 0.65, 0.7, 1)
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=200)
bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), 0, math.radians(30)))
bpy.context.object.data.energy = 3.0
# 人の大きさの目安(高さ 1.7m の柱)
bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=1.7, location=(3.0, 4.0, 0.85))
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
os.makedirs(render_dir, exist_ok=True)


def shoot(name, location, target):
    cam.location = location
    direction = Vector(target) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(render_dir, name)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)


shoot("train_front.png", (7.0, 16.0, 2.5), (0.0, 3.0, 1.8))
shoot("train_side.png", (22.0, -12.0, 4.0), (0.0, -12.0, 1.5))
