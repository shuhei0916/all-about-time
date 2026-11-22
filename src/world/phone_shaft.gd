class_name PhoneShaft
extends Node3D
## 電話ボックスで移る間に下る、地下の縦穴。街から見えない深い所に置く。
## 内部(PhoneBoothCar)はその場にとどまり、壁が下った深さだけ上へ流れて、下っているように見せる。
## 壁には地層の帯、配管、落書き、灯りを並べる。模様は PATTERN_LENGTH ごとに繰り返し、
## 上下に並べた写しでつなぎ目を隠す。模様は決まった種から作るので、いつも同じになる。

## 壁の模様の1回分の長さ(メートル)。
const PATTERN_LENGTH := 24.0
## 内部から上下にこれだけの範囲は、いつも壁で覆う(メートル)。
const VIEW_RANGE := 20.0
## 縦穴の内側の広さの半分と、壁の厚み(メートル)。内部(幅 1m)より少しだけ広い。
const HALF := 0.85
const WALL_THICKNESS := 0.1
## 模様を作る乱数の種。
const SEED := 20261122
## 縦穴の上下の端をふさぐ黒い蓋の、内部からの距離(メートル)。これより先は見えない。
const CAP_DISTANCE := VIEW_RANGE + 2.0

## 地下は空の光が届かないので、壁は環境光を受けず、内部の灯りと壁の灯りだけで照らす。
const WALL_SHADER_CODE := """
shader_type spatial;
render_mode ambient_light_disabled;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float metallic = 0.0;
uniform float roughness = 0.9;
void fragment() {
	ALBEDO = albedo.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
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

## 下った深さ(メートル)。壁はこれだけ上へ流れる。
var depth := 0.0:
	set(value):
		depth = value
		if is_node_ready():
			walls.position.y = fposmod(depth, PATTERN_LENGTH)

@onready var car: PhoneBoothCar = $Car
@onready var walls: Node3D = $Walls

var _rng := RandomNumberGenerator.new()
var _graffiti_texts: Array[String] = []
var _materials := {}
var _wall_shader: Shader


func _ready() -> void:
	_rng.seed = SEED
	var pattern := _build_pattern()
	for k in [-2, -1, 1, 0]:
		var copy: Node3D = pattern if k == 0 else pattern.duplicate()
		copy.position.y = k * PATTERN_LENGTH
		walls.add_child(copy)
	walls.position.y = fposmod(depth, PATTERN_LENGTH)
	_add_caps()


## 縦穴の上下の端を黒い蓋でふさぎ、その先(街の下など)が見えないようにする。
func _add_caps() -> void:
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	for y in [CAP_DISTANCE, -CAP_DISTANCE]:
		var box := BoxMesh.new()
		box.size = Vector3(2.0 * (HALF + WALL_THICKNESS), 0.2, 2.0 * (HALF + WALL_THICKNESS))
		box.material = black
		var cap := MeshInstance3D.new()
		cap.name = "CapTop" if y > 0.0 else "CapBottom"
		cap.mesh = box
		cap.position.y = y
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
	var lamp_material := StandardMaterial3D.new()
	lamp_material.albedo_color = Color(1.0, 0.8, 0.45)
	lamp_material.emission_enabled = true
	lamp_material.emission = Color(1.0, 0.75, 0.4)
	lamp_material.emission_energy_multiplier = 3.0
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


func _material(color: Color, metallic := 0.0) -> ShaderMaterial:
	var key := [color.to_html(), metallic]
	if not _materials.has(key):
		if _wall_shader == null:
			_wall_shader = Shader.new()
			_wall_shader.code = WALL_SHADER_CODE
		var material := ShaderMaterial.new()
		material.shader = _wall_shader
		material.set_shader_parameter(&"albedo", color)
		material.set_shader_parameter(&"metallic", metallic)
		material.set_shader_parameter(&"roughness", 0.9 if metallic == 0.0 else 0.4)
		_materials[key] = material
	return _materials[key]
