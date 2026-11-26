class_name PhoneBoothCar
extends Node3D
## 電話ボックスの内部(床、電話、行先の地図、天井の灯り)。移る時は、これが乗った人ごと沈み、降りてくる。
## 箱の外側(壁と屋根)は PhoneBooth に残る。原点は床の上面の中心で、箱の入口が +Z の側。
## 箱と縦穴は床と天井の穴(覗き窓)でつながっていて、内部は箱の側と縦穴の側に1つずつある。
## 穴の向こうへはみ出した所が見えないよう、切り取りの高さ(clip_bottom〜clip_top、世界の高さ)の外は映さない。
## 見た目は切り取れる材質に差し替え、文字と灯りは外に出たら隠す。

## 地図の上の、箱の番号の印の文字の大きさ。
const MARKER_FONT_SIZE := 36
const MARKER_COLOR := Color(1.0, 0.85, 0.2)
const HERE_COLOR := Color(1.0, 0.3, 0.25)
## 切り取らない時の、切り取りの高さ。
const NO_CLIP := 1.0e9

## 切り取りの高さより上を捨てる材質。地図用は光を受けない。
const CLIP_SHADER_CODE := """
shader_type spatial;
render_mode %s;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, hint_default_white;
uniform float metallic = 0.0;
uniform float roughness = 0.5;
uniform float clip_top = 1.0e9;
uniform float clip_bottom = -1.0e9;
uniform float ambient = 1.0;
varying float world_y;
void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	if (world_y > clip_top || world_y < clip_bottom) {
		discard;
	}
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	AO = ambient;
}
"""
static var _lit_shader: Shader
static var _unshaded_shader: Shader

## 切り取りの高さ(世界の高さ)。clip_top より上と clip_bottom より下は映さない。
var clip_top := NO_CLIP
var clip_bottom := -NO_CLIP
## 地下にあって空の光を受けないか。受けない時は、自分の灯りを切り取りの高さの外でも点けておく。
var underground := false:
	set(value):
		underground = value
		for material in _clip_materials:
			material.set_shader_parameter(&"ambient", 0.0 if value else 1.0)
		if is_node_ready():
			_update_hidden_parts()

@onready var phone: BoothPhone = $Phone
@onready var map_board: MeshInstance3D = $MapBoard
@onready var _screen: Label3D = $Phone/Screen
@onready var _lamp: Light3D = $Lamp

var _clip_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	for mesh: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(i) as BaseMaterial3D
			var material := _clip_material(false)
			if source:
				material.set_shader_parameter(&"albedo", source.albedo_color)
				material.set_shader_parameter(&"metallic", source.metallic)
				material.set_shader_parameter(&"roughness", source.roughness)
			mesh.set_surface_override_material(i, material)


func _process(_delta: float) -> void:
	_screen.text = phone.screen_text()
	_update_hidden_parts()


## 映す高さ(世界の高さ)を bottom から top までにする。
func set_clip(bottom: float, top: float) -> void:
	clip_bottom = bottom
	clip_top = top
	for material in _clip_materials:
		material.set_shader_parameter(&"clip_bottom", bottom)
		material.set_shader_parameter(&"clip_top", top)
	_update_hidden_parts()


## 映す高さの外にある文字と灯りを隠し、中にあれば出す。
func _update_hidden_parts() -> void:
	for label: Label3D in find_children("*", "Label3D", true, false):
		label.visible = _within_clip(label.global_position.y)
	_lamp.visible = underground or _within_clip(_lamp.global_position.y)


func _within_clip(y: float) -> bool:
	return y >= clip_bottom and y <= clip_top


func _clip_material(unshaded: bool) -> ShaderMaterial:
	if _lit_shader == null:
		_lit_shader = Shader.new()
		_lit_shader.code = CLIP_SHADER_CODE % "cull_back"
		_unshaded_shader = Shader.new()
		_unshaded_shader.code = CLIP_SHADER_CODE % "unshaded, cull_back"
	var material := ShaderMaterial.new()
	material.shader = _unshaded_shader if unshaded else _lit_shader
	material.set_shader_parameter(&"clip_top", clip_top)
	material.set_shader_parameter(&"clip_bottom", clip_bottom)
	material.set_shader_parameter(&"ambient", 0.0 if underground else 1.0)
	_clip_materials.append(material)
	return material


## 地図の絵 texture を掲示板に貼り、箱の番号の印を置く。
## markers は {"number": 番号, "uv": 地図の絵の上の位置(0〜1), "here": この箱か} の並び。
func show_map(texture: Texture2D, markers: Array) -> void:
	var material := _clip_material(true)
	material.set_shader_parameter(&"albedo_texture", texture)
	map_board.material_override = material
	for child in map_board.get_children():
		child.queue_free()
	# 掲示板の枠に収まるよう、地図の絵の縦横の比を保って大きさを決める。
	var frame: Vector2 = (map_board.mesh as QuadMesh).size
	var aspect := float(texture.get_width()) / texture.get_height()
	var size := Vector2(frame.x, frame.x / aspect) if aspect >= 1.0 else Vector2(frame.y * aspect, frame.y)
	var quad := QuadMesh.new()
	quad.size = size
	map_board.mesh = quad
	for marker: Dictionary in markers:
		var label := Label3D.new()
		label.text = ("● " if marker.here else "") + marker.number
		label.font_size = MARKER_FONT_SIZE
		label.pixel_size = 0.0008
		label.outline_size = 8
		label.modulate = HERE_COLOR if marker.here else MARKER_COLOR
		var uv: Vector2 = marker.uv
		label.position = Vector3((uv.x - 0.5) * size.x, (0.5 - uv.y) * size.y, 0.002)
		map_board.add_child(label)
	_update_hidden_parts()
