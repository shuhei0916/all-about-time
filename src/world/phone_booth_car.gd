class_name PhoneBoothCar
extends Node3D
## 電話ボックスの内部(床、電話、行先の地図、天井の灯り)。移る時は、これが乗った人ごと沈み、降りてくる。
## 箱の外側(壁と屋根)は PhoneBooth に残る。原点は床の上面の中心で、箱の入口が +Z の側。
## 天井から降りてくる時に天井の上がはみ出して見えないよう、切り取りの高さ(clip_top、世界の高さ)より
## 上は映さない。見た目は切り取れる材質に差し替え、文字と灯りは高さを越えたら隠す。

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
varying float world_y;
void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	if (world_y > clip_top) {
		discard;
	}
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
"""
static var _lit_shader: Shader
static var _unshaded_shader: Shader

## 切り取りの高さ(世界の高さ)。これより上は映さない。
var clip_top := NO_CLIP

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


## 切り取りの高さ(世界の高さ)を y にする。
func set_clip_top(y: float) -> void:
	clip_top = y
	for material in _clip_materials:
		material.set_shader_parameter(&"clip_top", y)
	_update_hidden_parts()


## 切り取りの高さより上にある文字と灯りを隠し、下にあれば出す。
func _update_hidden_parts() -> void:
	for label: Label3D in find_children("*", "Label3D", true, false):
		label.visible = label.global_position.y <= clip_top
	_lamp.visible = _lamp.global_position.y <= clip_top


func _clip_material(unshaded: bool) -> ShaderMaterial:
	if _lit_shader == null:
		_lit_shader = Shader.new()
		_lit_shader.code = CLIP_SHADER_CODE % "cull_back"
		_unshaded_shader = Shader.new()
		_unshaded_shader.code = CLIP_SHADER_CODE % "unshaded, cull_back"
	var material := ShaderMaterial.new()
	material.shader = _unshaded_shader if unshaded else _lit_shader
	material.set_shader_parameter(&"clip_top", clip_top)
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
