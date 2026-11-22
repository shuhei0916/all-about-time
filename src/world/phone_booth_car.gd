class_name PhoneBoothCar
extends Node3D
## 電話ボックスの内部(床、電話、行先の地図、天井の灯り)。移る時は、これが乗った人ごと沈み、降りてくる。
## 箱の外側(壁と屋根)は PhoneBooth に残る。原点は床の上面の中心で、箱の入口が +Z の側。

## 地図の上の、箱の番号の印の文字の大きさ。
const MARKER_FONT_SIZE := 36
const MARKER_COLOR := Color(1.0, 0.85, 0.2)
const HERE_COLOR := Color(1.0, 0.3, 0.25)

@onready var phone: BoothPhone = $Phone
@onready var map_board: MeshInstance3D = $MapBoard
@onready var _screen: Label3D = $Phone/Screen


func _process(_delta: float) -> void:
	_screen.text = phone.screen_text()


## 地図の絵 texture を掲示板に貼り、箱の番号の印を置く。
## markers は {"number": 番号, "uv": 地図の絵の上の位置(0〜1), "here": この箱か} の並び。
func show_map(texture: Texture2D, markers: Array) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	map_board.material_override = material
	for child in map_board.get_children():
		child.queue_free()
	var size: Vector2 = (map_board.mesh as QuadMesh).size
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
