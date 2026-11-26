class_name PhoneShaft
extends Node3D
## 電話ボックスの下の、地下の縦穴。箱ごとに1つあり、街から見えない深い所に置く。
## 上の口(高さ TOP_PLANE)は箱の床の穴に、下の口(高さ bottom_plane())は箱の天井の穴につながっていて、
## 箱の中の高さ y の所は、床の穴を通すと縦穴の高さ y に、天井の穴を通すと縦穴の高さ y - DROP に写る。
## 縦穴の内部(car)は箱の内部と対になって動き、穴の向こうに見える。
## 壁には地層の帯、配管、落書き、灯りを並べる。模様は PATTERN_LENGTH ごとに繰り返し、決まった種から作るので、
## どの縦穴も同じになる。別の縦穴へ乗り換える時は、壁をずらして模様の位置をそろえる。

## 壁の模様の1回分の長さ(メートル)。
const PATTERN_LENGTH := 24.0
## 縦穴の内側の広さの半分と、壁の厚み(メートル)。内部(幅 1m)より少しだけ広い。
const HALF := 0.85
const WALL_THICKNESS := 0.1
## 模様を作る乱数の種。
const SEED := 20261122
## 上の口の高さ。箱の床の穴と同じ高さ。
const TOP_PLANE := PhoneBooth.FLOOR_PLANE
## 天井の穴を通した時の、縦穴での下がり方(メートル)。上の口から下の口までの長さの目安。
const DROP := 72.0
## 縦穴を下り続けてこれより深くなったら、模様1回分ずつ上へ戻す(メートル)。
## 戻した後も、上の口と下の口が穴の向こうを描く距離(DOOR_VIEW_DISTANCE)より遠くにあるようにする。
const WRAP_DEPTH := 44.0
## 縦穴の口から穴の向こう(箱)を描く距離(メートル)。縦穴の奥から遠くの口の向こうは描かない。
const DOOR_VIEW_DISTANCE := 16.0
## 口の外側をふさぐ黒い蓋の、口からの距離(メートル)。覗き窓より外に置く。
const CAP_OFFSET := 0.15

## 地下は空の光が届かないので、壁は環境光を受けず、内部の灯りと壁の灯りだけで照らす。
## 口の外へはみ出した所は、箱の穴から覗いた時に景色を遮らないよう映さない。
const WALL_SHADER_CODE := """
shader_type spatial;
render_mode ambient_light_disabled;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float metallic = 0.0;
uniform float roughness = 0.9;
uniform vec3 emission : source_color = vec3(0.0);
uniform float clip_top = 1.0e9;
uniform float clip_bottom = -1.0e9;
varying float world_y;
void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	if (world_y > clip_top || world_y < clip_bottom) {
		discard;
	}
	ALBEDO = albedo.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = emission;
}
"""

const STRATA_COLORS: Array[Color] = [
	Color(0.42, 0.33, 0.24), Color(0.55, 0.45, 0.32), Color(0.3, 0.26, 0.22),
	Color(0.48, 0.38, 0.3), Color(0.25, 0.22, 0.2), Color(0.6, 0.52, 0.4),
]
const CONCRETE_COLOR := Color(0.58, 0.57, 0.54)
const PIPE_COLORS: Array[Color] = [Color(0.45, 0.22, 0.12), Color(0.2, 0.32, 0.25), Color(0.5, 0.5, 0.52)]
const GRAFFITI_COLORS: Array[Color] = [
	Color(1.0, 0.25, 0.3), Color(0.2, 0.9, 1.0), Color(1.0, 0.85, 0.1), Color(0.6, 1.0, 0.3), Color(1.0, 1.0, 1.0),
]
const GRAFFITI: Array[String] = [
	"TIME IS MONEY", "時は金なり", "ここから出して", "残り 3日", "誰が時計を進めた", "101 → 204",
	"||||  ||||  ||", "09:00", "まだ月曜", "WHO OWNS TIME?", "降りても降りても", "上も下も同じ",
]

@onready var car: PhoneBoothCar = $Car
@onready var walls: Node3D = $Walls

## 上の口と下の口。箱の床の穴と天井の穴につなぐ。
var top_door: PassageDoor
var bottom_door: PassageDoor

var _rng := RandomNumberGenerator.new()
var _graffiti_texts: Array[String] = []
var _graffiti: Array[Label3D] = []
var _materials := {}
var _wall_shader: Shader


## 下の口の高さ。箱の天井の穴を通した高さ。
static func bottom_plane() -> float:
	return PhoneBooth.CEILING_PLANE - DROP


## 下った高さ y が深すぎたら、模様1回分ずつ上へ戻す。壁の模様は繰り返すので、戻しても見た目は変わらない。
static func wrap(y: float) -> float:
	while y < -WRAP_DEPTH:
		y += PATTERN_LENGTH
	return y


func _ready() -> void:
	car.underground = true
	_rng.seed = SEED
	var pattern := _build_pattern()
	for k in [-4, -3, -2, -1, 0]:
		var copy: Node3D = pattern if k == 0 else pattern.duplicate()
		copy.position.y = k * PATTERN_LENGTH
		walls.add_child(copy)
	for label: Label3D in walls.find_children("*", "Label3D", true, false):
		_graffiti.append(label)
	var turn := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	top_door = _add_door("TopDoor", PhoneBooth.floor_door_transform() * turn)
	bottom_door = _add_door("BottomDoor", Transform3D(Basis(), Vector3(0, -DROP, 0)) * PhoneBooth.ceiling_door_transform() * turn)
	_add_caps()
	_update_clip()


## 箱 booth の床の穴と天井の穴に、上の口と下の口をつなぐ。
func link(booth: PhoneBooth) -> void:
	top_door.destination = booth.floor_door
	bottom_door.destination = booth.ceiling_door
	_update_clip()


func set_car_height(y: float) -> void:
	car.position.y = y


func car_height() -> float:
	return car.position.y


## 壁を offset だけ上へずらす。模様1回分ごとに元に戻る。
func set_walls_offset(offset: float) -> void:
	walls.position.y = fposmod(offset, PATTERN_LENGTH)
	_update_clip()


## 縦穴の高さ y の所が、壁の模様1回分のどこに当たるか(0〜PATTERN_LENGTH)。
func pattern_phase(y: float) -> float:
	return fposmod(y - walls.position.y, PATTERN_LENGTH)


## 壁と内部を映す高さの上端と下端(世界の高さ)。
func wall_clip_top() -> float:
	return global_position.y + TOP_PLANE


func wall_clip_bottom() -> float:
	return global_position.y + bottom_plane()


## 口の外へはみ出した壁、内部、落書きを映さないようにする。
func _update_clip() -> void:
	if not is_inside_tree():
		return
	var top := wall_clip_top()
	var bottom := wall_clip_bottom()
	car.set_clip(bottom, top)
	for material: ShaderMaterial in _materials.values():
		material.set_shader_parameter(&"clip_top", top)
		material.set_shader_parameter(&"clip_bottom", bottom)
	for label in _graffiti:
		var y := label.global_position.y
		label.visible = y <= top and y >= bottom


func _add_door(door_name: String, frame: Transform3D) -> PassageDoor:
	var door := PassageDoor.new()
	door.name = door_name
	door.size = Vector2.ONE * 2.0 * PhoneBooth.INNER_HALF
	door.carries = false
	door.max_view_distance = DOOR_VIEW_DISTANCE
	door.transform = frame
	add_child(door)
	return door


## 上の口の上と下の口の下を黒い蓋でふさぐ。口の覗き窓が開いていない時(遠い時)に、その先が見えないようにする。
## 箱の穴から覗くカメラには映さない。
func _add_caps() -> void:
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	for y in [TOP_PLANE + CAP_OFFSET, bottom_plane() - CAP_OFFSET]:
		var box := BoxMesh.new()
		box.size = Vector3(2.0 * (HALF + WALL_THICKNESS), 0.1, 2.0 * (HALF + WALL_THICKNESS))
		box.material = black
		var cap := MeshInstance3D.new()
		cap.name = "CapTop" if y > 0.0 else "CapBottom"
		cap.mesh = box
		cap.position.y = y
		cap.layers = 0
		cap.set_layer_mask_value(PassageDoor.HIDDEN_LAYER, true)
		add_child(cap)


## 壁に書いた落書きの文字(模様1回分)。
func graffiti_texts() -> Array[String]:
	return _graffiti_texts


## 模様1回分(高さ 0 から PATTERN_LENGTH まで)の壁を作る。
func _build_pattern() -> Node3D:
	var pattern := Node3D.new()
	pattern.name = "Pattern"
	_add_strata(pattern)
	_add_pipes(pattern)
	_add_lamps(pattern)
	_add_graffiti(pattern)
	return pattern


## 地層の帯。ときどきコンクリートで固めた帯と、その継ぎ目をはさむ。
func _add_strata(pattern: Node3D) -> void:
	var y := 0.0
	while y < PATTERN_LENGTH - 0.01:
		var height := minf(_rng.randf_range(0.6, 2.8), PATTERN_LENGTH - y)
		var concrete := _rng.randf() < 0.2
		var color := CONCRETE_COLOR if concrete else STRATA_COLORS[_rng.randi() % STRATA_COLORS.size()]
		color = color.lightened(_rng.randf_range(-0.08, 0.08))
		for side in 4:
			_add_wall_box(pattern, side, y, height, color, 0.0)
		if concrete:
			for side in 4:
				_add_wall_box(pattern, side, y + height - 0.04, 0.04, color.darkened(0.5), 0.01)
		y += height


## 内側の面が side(0: +X, 1: -X, 2: +Z, 3: -Z)の壁の、高さ y から height の箱。inset だけ内側へ出す。
func _add_wall_box(pattern: Node3D, side: int, y: float, height: float, color: Color, inset: float) -> void:
	var box := BoxMesh.new()
	var span := 2.0 * (HALF + WALL_THICKNESS)
	var offset := HALF + WALL_THICKNESS / 2.0 - inset
	var center := Vector3.ZERO
	if side < 2:
		box.size = Vector3(WALL_THICKNESS, height, span)
		center.x = offset if side == 0 else -offset
	else:
		box.size = Vector3(span, height, WALL_THICKNESS)
		center.z = offset if side == 2 else -offset
	center.y = y + height / 2.0
	box.material = _material(color)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = center
	pattern.add_child(mesh)


## 隅を縦に通る配管(模様の端から端まで続くので、つなぎ目がない)と、壁に沿って横に渡る配管。
func _add_pipes(pattern: Node3D) -> void:
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	for i in 3:
		var corner: Vector2 = corners[i] * (HALF - 0.12)
		var pipe := _pipe(_rng.randf_range(0.04, 0.08), PATTERN_LENGTH, PIPE_COLORS[i % PIPE_COLORS.size()])
		pipe.position = Vector3(corner.x, PATTERN_LENGTH / 2.0, corner.y)
		pattern.add_child(pipe)
	for i in 5:
		var pipe := _pipe(_rng.randf_range(0.03, 0.07), 2.0 * HALF, PIPE_COLORS[_rng.randi() % PIPE_COLORS.size()])
		var y := _rng.randf_range(0.5, PATTERN_LENGTH - 0.5)
		var along := HALF - 0.07
		match _rng.randi() % 4:
			0:
				pipe.rotation_degrees.x = 90.0
				pipe.position = Vector3(along, y, 0)
			1:
				pipe.rotation_degrees.x = 90.0
				pipe.position = Vector3(-along, y, 0)
			2:
				pipe.rotation_degrees.z = 90.0
				pipe.position = Vector3(0, y, along)
			_:
				pipe.rotation_degrees.z = 90.0
				pipe.position = Vector3(0, y, -along)
		pattern.add_child(pipe)


func _pipe(radius: float, length: float, color: Color) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 12
	cylinder.material = _material(color, 0.6)
	var mesh := MeshInstance3D.new()
	mesh.mesh = cylinder
	return mesh


## 壁の灯り。光るだけで周りは照らさず、流れていく目印にする。
func _add_lamps(pattern: Node3D) -> void:
	var lamp_material := _material(Color(1.0, 0.8, 0.45), 0.0, Color(1.0, 0.75, 0.4) * 3.0)
	var y := 3.0
	var side := 0
	while y < PATTERN_LENGTH:
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.2, 0.12)
		box.material = lamp_material
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		var normal := _inward_normal(side)
		mesh.position = -normal * (HALF - 0.05) + Vector3(0, y, 0)
		pattern.add_child(mesh)
		y += 6.0
		side = (side + 1) % 4


## 落書き。壁の内側の面に、文字を少し傾けて書く。
func _add_graffiti(pattern: Node3D) -> void:
	for i in 9:
		var text := GRAFFITI[_rng.randi() % GRAFFITI.size()]
		_graffiti_texts.append(text)
		var side := _rng.randi() % 4
		var normal := _inward_normal(side)
		var label := Label3D.new()
		label.text = text
		label.font_size = 64
		label.pixel_size = _rng.randf_range(0.002, 0.004)
		label.outline_size = 0
		label.shaded = true
		label.modulate = GRAFFITI_COLORS[_rng.randi() % GRAFFITI_COLORS.size()]
		var across := _rng.randf_range(-0.3, 0.3)
		var y := _rng.randf_range(0.5, PATTERN_LENGTH - 0.5)
		var wall_point := -normal * (HALF - 0.005)
		var tangent := Vector3(-normal.z, 0, normal.x)
		label.position = wall_point + tangent * across + Vector3(0, y, 0)
		label.basis = Basis.looking_at(normal, Vector3.UP, true) * Basis(Vector3.BACK, _rng.randf_range(-0.25, 0.25))
		pattern.add_child(label)


## side(0: +X, 1: -X, 2: +Z, 3: -Z)の壁の、内側へ向かう向き。
func _inward_normal(side: int) -> Vector3:
	return [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK][side]


func _material(color: Color, metallic := 0.0, emission := Color.BLACK) -> ShaderMaterial:
	var key := [color.to_html(), metallic, emission.to_html()]
	if not _materials.has(key):
		if _wall_shader == null:
			_wall_shader = Shader.new()
			_wall_shader.code = WALL_SHADER_CODE
		var material := ShaderMaterial.new()
		material.shader = _wall_shader
		material.set_shader_parameter(&"albedo", color)
		material.set_shader_parameter(&"metallic", metallic)
		material.set_shader_parameter(&"roughness", 0.9 if metallic == 0.0 else 0.4)
		material.set_shader_parameter(&"emission", Vector3(emission.r, emission.g, emission.b))
		_materials[key] = material
	return _materials[key]
