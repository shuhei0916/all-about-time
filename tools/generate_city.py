"""Downtown City MegaKit の部品を並べて、街のシーン src/world/city/city.tscn を生成する。

    python tools/generate_city.py

道路を格子状に敷き、区画の縁に建物を正面を道路へ向けて並べる。乱数の種を固定しているので、
何度実行しても同じ街になる。生成した街をエディタで手直しした後に実行すると、手直しは消える。

寸法は部品の実測値(メートル)。建物は正面が +Z で、原点は正面の入口のあたりにある。
"""

import math
import random
from pathlib import Path

SEED = 7
# 道路は LINES 本 × LINES 本の格子。区画は (LINES - 1) × (LINES - 1)。
LINES = 5
# 十字路の一辺と、十字路の間をつなぐ直線の区間の長さ・本数。
INTERSECTION = 24.67
SEGMENT = 6.0
SEGMENTS_PER_SPAN = 6
PITCH = INTERSECTION + SEGMENT * SEGMENTS_PER_SPAN
# 道路の幅(歩道込み)。区画はこの半分だけ道路の中心線から離れて始まる。
STREET_WIDTH = 12.0
# 外周の道路を、外へ何区間延ばして行き止まりにするか。
DEAD_END_SEGMENTS = 3
# 建物の正面を区画の縁から下げる距離。
SETBACK = 0.3
# 建物どうしの最小の隙間。
MIN_GAP = 0.2

KIT = "res://assets/Downtown City MegaKit[Standard]/Exports/glTF (Godot)/"
OUT = Path(__file__).resolve().parent.parent / "src" / "world" / "city" / "city.tscn"

# 建物の見た目の範囲(部品の原点から見た X と Z の範囲、高さ)。
BUILDINGS = {
    "Building_Small_1": ((-7.23, 5.23), (-12.23, 2.31), 17.03),
    "Building_Medium_2_001": ((-7.53, 7.53), (-12.49, 0.57), 25.01),
    "Building_Large_2": ((-9.32, 11.32), (-16.32, 0.32), 28.0),
}

rng = random.Random(SEED)


def line_position(index: int) -> float:
    """道路の中心線の位置。街の中心が原点になるように並べる。"""
    return (index - (LINES - 1) / 2) * PITCH


class Scene:
    """tscn を組み立てる。"""

    def __init__(self) -> None:
        self.ext: dict[str, str] = {}
        self.ext_lines: list[str] = []
        self.sub_lines: list[str] = []
        self.node_lines: list[str] = []
        self.names: dict[str, int] = {}

    def ext_id(self, path: str, kind: str = "PackedScene") -> str:
        if path not in self.ext:
            rid = f"{len(self.ext) + 1}_ext"
            self.ext[path] = rid
            self.ext_lines.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
        return self.ext[path]

    def sub(self, text: str) -> None:
        self.sub_lines.append(text)

    def unique(self, base: str) -> str:
        self.names[base] = self.names.get(base, 0) + 1
        return f"{base}{self.names[base]}"

    def node(self, header: str, body: str = "") -> None:
        self.node_lines.append(header + ("\n" + body if body else ""))

    def instance(self, piece: str, parent: str, position, yaw_degrees: float = 0.0, groups=None, name=None) -> None:
        rid = self.ext_id(KIT + piece + ".gltf")
        name = name or self.unique(piece)
        group_text = f" groups=[{', '.join(repr_str(g) for g in groups)}]" if groups else ""
        self.node(
            f'[node name="{name}" parent="{parent}" instance=ExtResource("{rid}"){group_text}]',
            f"transform = {transform(position, yaw_degrees)}",
        )

    def write(self, path: Path) -> None:
        text = "[gd_scene format=3]\n\n" + "\n".join(self.ext_lines) + "\n\n"
        text += "\n\n".join(self.sub_lines) + "\n\n" + "\n\n".join(self.node_lines) + "\n"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")


def repr_str(s: str) -> str:
    return '"' + s + '"'


def transform(position, yaw_degrees: float) -> str:
    """Y 軸回りに yaw 度回して position に置く Transform3D(行ごとに並べる)。"""
    a = math.radians(yaw_degrees)
    c, s = round(math.cos(a), 6), round(math.sin(a), 6)
    x, y, z = (round(v, 4) for v in position)
    return f"Transform3D({c}, 0, {s}, 0, 1, 0, {-s}, 0, {c}, {x}, {y}, {z})"


def rotate(x: float, z: float, yaw_degrees: float) -> tuple[float, float]:
    a = math.radians(yaw_degrees)
    return (x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a))


def world_footprint(name: str, origin, yaw: float):
    """建物を origin に yaw 度で置いた時の、ワールドでの X と Z の範囲。"""
    (x0, x1), (z0, z1), _ = BUILDINGS[name]
    corners = [rotate(x, z, yaw) for x in (x0, x1) for z in (z0, z1)]
    xs = [origin[0] + cx for cx, _ in corners]
    zs = [origin[2] + cz for _, cz in corners]
    return (min(xs), max(xs)), (min(zs), max(zs))


def build_streets(scene: Scene) -> None:
    scene.node('[node name="Streets" type="Node3D" parent="."]')
    first, last = line_position(0), line_position(LINES - 1)
    half = INTERSECTION / 2
    for i in range(LINES):
        for j in range(LINES):
            scene.instance("Street_4WayIntersection", "Streets", (line_position(i), 0, line_position(j)), groups=["street"])
    for line in range(LINES):
        along = line_position(line)
        # 十字路の間と、外周から外への延長。
        starts = [line_position(k) + half for k in range(LINES - 1)]
        runs = [(s, SEGMENTS_PER_SPAN) for s in starts]
        runs.append((last + half, DEAD_END_SEGMENTS))
        runs.append((first - half - SEGMENT * DEAD_END_SEGMENTS, DEAD_END_SEGMENTS))
        for start, count in runs:
            for k in range(count):
                c = start + SEGMENT * (k + 0.5)
                # 東西の道(X 方向に延びる)と南北の道(Z 方向に延びる)。
                scene.instance("Street_2Lane", "Streets", (c, 0, along), 0, groups=["street"])
                scene.instance("Street_2Lane", "Streets", (along, 0, c), 90, groups=["street"])
        # 行き止まりに車止めを並べる。
        for end in (last + half + SEGMENT * DEAD_END_SEGMENTS, first - half - SEGMENT * DEAD_END_SEGMENTS):
            for n in range(9):
                across = along - 4.8 + n * 1.2
                scene.instance("Prop_Bollard", "Streets", (end, 0, across))
                scene.instance("Prop_Bollard", "Streets", (across, 0, end))


def fill_row(length: float) -> tuple[list[str], float]:
    """長さ length の縁に収まるよう、建物を乱数で選んで並べる。選んだ建物と隙間を返す。"""
    names = list(BUILDINGS)
    row: list[str] = []
    used = 0.0
    while True:
        fitting = [n for n in names if used + width(n) + MIN_GAP * (len(row) + 1) <= length]
        if not fitting:
            break
        pick = rng.choice(fitting)
        row.append(pick)
        used += width(pick)
    gap = (length - used) / (len(row) + 1) if row else 0.0
    return row, gap


def width(name: str) -> float:
    (x0, x1), _, _ = BUILDINGS[name]
    return x1 - x0


def depth(name: str) -> float:
    _, (z0, z1), _ = BUILDINGS[name]
    return z1 - z0


def place_row(scene: Scene, row, gap, edge: str, block, start: float) -> float:
    """区画 block の縁 edge に、row の建物を start から並べる。並べた建物の最大の奥行きを返す。"""
    (bx0, bx1), (bz0, bz1) = block
    yaw = {"south": 0, "north": 180, "east": 90, "west": -90}[edge]
    cursor = start + gap
    deepest = 0.0
    for name in row:
        (lx0, lx1), (lz0, lz1), _height = BUILDINGS[name]
        w = lx1 - lx0
        # 並べる方向に沿った建物の中心と、正面の位置から原点を決める。
        mid_local = (lx0 + lx1) / 2
        if edge == "south":
            origin = (cursor + w / 2 - mid_local, 0, bz1 - SETBACK - lz1)
        elif edge == "north":
            origin = (cursor + w / 2 + mid_local, 0, bz0 + SETBACK + lz1)
        elif edge == "east":
            origin = (bx1 - SETBACK - lz1, 0, cursor + w / 2 + mid_local)
        else:
            origin = (bx0 + SETBACK + lz1, 0, cursor + w / 2 - mid_local)
        scene.instance(name, "Buildings", origin, yaw, groups=["building"])
        cursor += w + gap
        deepest = max(deepest, depth(name) + SETBACK)
    return deepest


def build_blocks(scene: Scene) -> None:
    scene.node('[node name="Buildings" type="Node3D" parent="."]')
    scene.node('[node name="Plazas" type="Node3D" parent="."]')
    inner = STREET_WIDTH / 2
    plazas = {(1, 1), (2, 2)}
    for i in range(LINES - 1):
        for j in range(LINES - 1):
            block = ((line_position(i) + inner, line_position(i + 1) - inner), (line_position(j) + inner, line_position(j + 1) - inner))
            if (i, j) in plazas:
                build_plaza(scene, block)
                continue
            (bx0, bx1), (bz0, bz1) = block
            south, south_gap = fill_row(bx1 - bx0)
            north, north_gap = fill_row(bx1 - bx0)
            d_south = place_row(scene, south, south_gap, "south", block, bx0)
            d_north = place_row(scene, north, north_gap, "north", block, bx0)
            side_start, side_end = bz0 + d_north + MIN_GAP, bz1 - d_south - MIN_GAP
            for edge in ("east", "west"):
                row, gap = fill_row(side_end - side_start)
                place_row(scene, row, gap, edge, block, side_start)


def build_plaza(scene: Scene, block) -> None:
    """建物を建てず、植え込みを格子状に置いた広場にする。"""
    (bx0, bx1), (bz0, bz1) = block
    for n in range(5):
        for m in range(5):
            x = bx0 + (bx1 - bx0) * (n + 0.5) / 5
            z = bz0 + (bz1 - bz0) * (m + 0.5) / 5
            scene.instance("Prop_Planter_Single", "Plazas", (x, 0, z))


def build_lamps(scene: Scene) -> None:
    """キットに街灯がないので、仮の柱と暖色の明かりを歩道に並べる。"""
    scene.sub('[sub_resource type="StandardMaterial3D" id="mat_lamp_pole"]\nalbedo_color = Color(0.12, 0.12, 0.13, 1)\nmetallic = 0.5\nroughness = 0.5')
    scene.sub('[sub_resource type="CylinderMesh" id="mesh_lamp_pole"]\nmaterial = SubResource("mat_lamp_pole")\ntop_radius = 0.07\nbottom_radius = 0.1\nheight = 5.0')
    scene.sub('[sub_resource type="StandardMaterial3D" id="mat_lamp_head"]\nalbedo_color = Color(1, 0.85, 0.6, 1)\nemission_enabled = true\nemission = Color(1, 0.75, 0.45, 1)\nemission_energy_multiplier = 3.0')
    scene.sub('[sub_resource type="BoxMesh" id="mesh_lamp_head"]\nmaterial = SubResource("mat_lamp_head")\nsize = Vector3(0.5, 0.15, 0.3)')
    scene.node('[node name="Lamps" type="Node3D" parent="."]')
    half = INTERSECTION / 2
    offset = STREET_WIDTH / 2 - 0.6
    for line in range(LINES):
        along = line_position(line)
        for k in range(LINES - 1):
            start = line_position(k) + half
            for n, side in ((1, 1), (4, -1)):
                c = start + SEGMENT * (n + 0.5)
                for position in ((c, along + side * offset), (along + side * offset, c)):
                    name = scene.unique("Lamp")
                    x, z = position
                    scene.node(f'[node name="{name}" type="Node3D" parent="Lamps"]', f"transform = {transform((x, 0, z), 0)}")
                    scene.node(f'[node name="Pole" type="MeshInstance3D" parent="Lamps/{name}"]', f'transform = {transform((0, 2.5, 0), 0)}\nmesh = SubResource("mesh_lamp_pole")')
                    scene.node(f'[node name="Head" type="MeshInstance3D" parent="Lamps/{name}"]', f'transform = {transform((0, 5.0, 0), 0)}\nmesh = SubResource("mesh_lamp_head")')
                    scene.node(
                        f'[node name="Light" type="OmniLight3D" parent="Lamps/{name}"]',
                        f'transform = {transform((0, 4.8, 0), 0)}\nlight_color = Color(1, 0.78, 0.5, 1)\nlight_energy = 1.6\nomni_range = 13.0',
                    )


def build_ground(scene: Scene) -> float:
    """区画の内側と十字路の四隅の隙間を、歩道と同じ高さのコンクリートで埋める。

    1枚で街全体を覆うと、歩道より低い車道のアスファルトまで隠れてしまうので、区画ごとに敷く。
    街の外は、車道より低い所に1枚敷いて、行き止まりの先の地面にする。
    """
    size = PITCH * (LINES - 1) + INTERSECTION + SEGMENT * DEAD_END_SEGMENTS * 2 + 20
    albedo = scene.ext_id(KIT + "T_Concrete_BaseColor.png", "Texture2D")
    normal = scene.ext_id(KIT + "T_Concrete_Normal.png", "Texture2D")
    # テクスチャ1枚を3m四方に貼る。ワールド座標で貼ると、区画ごとの継ぎ目が出ない。
    scene.sub(
        '[sub_resource type="StandardMaterial3D" id="mat_ground"]\n'
        f'albedo_texture = ExtResource("{albedo}")\nnormal_enabled = true\nnormal_texture = ExtResource("{normal}")\n'
        "uv1_scale = Vector3(0.3333, 0.3333, 0.3333)\nuv1_triplanar = true\nuv1_world_triplanar = true\nroughness = 0.9"
    )
    block = PITCH - STREET_WIDTH
    scene.sub(f'[sub_resource type="PlaneMesh" id="mesh_block_ground"]\nmaterial = SubResource("mat_ground")\nsize = Vector2({block:.3f}, {block:.3f})')
    scene.sub(f'[sub_resource type="PlaneMesh" id="mesh_outskirts"]\nmaterial = SubResource("mat_ground")\nsize = Vector2({size}, {size})')
    scene.node('[node name="Ground" type="Node3D" parent="."]')
    scene.node('[node name="Outskirts" type="MeshInstance3D" parent="Ground"]', f'transform = {transform((0, -0.3, 0), 0)}\nmesh = SubResource("mesh_outskirts")')
    for i in range(LINES - 1):
        for j in range(LINES - 1):
            x = (line_position(i) + line_position(i + 1)) / 2
            z = (line_position(j) + line_position(j + 1)) / 2
            scene.node(f'[node name="Block{i}{j}" type="MeshInstance3D" parent="Ground"]', f'transform = {transform((x, -0.005, z), 0)}\nmesh = SubResource("mesh_block_ground")')
    return size


def build_colliders(scene: Scene, ground_size: float) -> None:
    """地面の当たり判定。道路、歩道、建物、小物は、読み込み時に部品ごとに当たり判定が付く
    (tools/kit_post_import.gd)ので、ここでは区画の地面と街の外の地面だけを作る。
    """
    scene.node('[node name="GroundColliders" type="StaticBody3D" parent="."]')
    block = PITCH - STREET_WIDTH
    boxes = [("Outskirts", 0, -0.3, 0, ground_size)]
    for i in range(LINES - 1):
        for j in range(LINES - 1):
            x = (line_position(i) + line_position(i + 1)) / 2
            z = (line_position(j) + line_position(j + 1)) / 2
            boxes.append((f"Block{i}{j}", x, -0.005, z, block))
    scene.sub(f'[sub_resource type="BoxShape3D" id="shape_outskirts"]\nsize = Vector3({ground_size:.3f}, 1.0, {ground_size:.3f})')
    scene.sub(f'[sub_resource type="BoxShape3D" id="shape_block"]\nsize = Vector3({block:.3f}, 1.0, {block:.3f})')
    for name, x, top, z, _size in boxes:
        shape = "shape_outskirts" if name == "Outskirts" else "shape_block"
        scene.node(f'[node name="{name}" type="CollisionShape3D" parent="GroundColliders"]', f'transform = {transform((x, top - 0.5, z), 0)}\nshape = SubResource("{shape}")')


def main() -> None:
    scene = Scene()
    scene.node('[node name="City" type="Node3D"]')
    ground_size = build_ground(scene)
    build_streets(scene)
    build_blocks(scene)
    build_lamps(scene)
    build_colliders(scene, ground_size)
    scene.write(OUT)
    print(f"wrote {OUT} (ground {ground_size:.0f}m)")


if __name__ == "__main__":
    main()
