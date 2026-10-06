class_name PromptLabel
extends Node3D
## 物の上に浮かび、常にカメラを向く操作案内。プレイヤーが見ている間だけ出す。
## キーの絵と操作の文言の組を、左から横に並べる。
## 物の見た目の一番上から少し離れた真上に出し、物が転がって傾いても一緒には傾かない。

## 見た目がない物で、原点から持ち上げる高さ(メートル)。
const DEFAULT_HEIGHT := 0.4
## 見た目の一番上から離す距離(メートル)。
const MARGIN := 0.15
## キーの絵。絵のないキーは文字で出す。
const KEY_ICONS := {
	"E": preload("res://assets/ui/input_prompts/keyboard_e.png"),
	"F": preload("res://assets/ui/input_prompts/keyboard_f.png"),
	"Q": preload("res://assets/ui/input_prompts/keyboard_q.png"),
}
## キーの絵の高さ(メートル)。
const KEY_SIZE := 0.17
const FONT_SIZE := 60
## 文字の1ピクセルの大きさ(メートル)。
const TEXT_PIXEL_SIZE := 0.002
## キーの絵と、その操作の文言の間(メートル)。
const KEY_GAP := 0.02
## 操作の組と組の間(メートル)。
const ENTRY_GAP := 0.1

## 今出している、キーと操作の文言の組の並び。
var _entries: Array = []


func _init() -> void:
	position.y = DEFAULT_HEIGHT
	# 物の回転に付いていかないよう、位置は place_above でワールド座標として決める。
	top_level = true
	hide()


## 横幅 widths の部品を、間 gaps(部品の数より1つ少ない)を空けて左から並べた時の、
## それぞれの中心の位置。並び全体の中央が 0 になる。
static func row_centers(widths: Array[float], gaps: Array[float]) -> Array[float]:
	var total := 0.0
	for width in widths:
		total += width
	for gap in gaps:
		total += gap
	var centers: Array[float] = []
	var left := -total / 2.0
	for i in widths.size():
		centers.append(left + widths[i] / 2.0)
		left += widths[i] + (gaps[i] if i < gaps.size() else 0.0)
	return centers


## キーと操作の文言の組 [キー, 文言] の並びを出す。前と同じなら作り直さない。
func set_entries(entries: Array) -> void:
	if entries == _entries:
		return
	_entries = entries.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.free()
	var parts: Array[Node3D] = []
	var gaps: Array[float] = []
	for entry: Array in entries:
		if not parts.is_empty():
			gaps.append(ENTRY_GAP)
		parts.append(_make_key(entry[0]))
		gaps.append(KEY_GAP)
		parts.append(_make_text(entry[1]))
	var widths: Array[float] = []
	for part in parts:
		widths.append(_width_of(part))
	var centers := row_centers(widths, gaps)
	for i in parts.size():
		parts[i].offset.x = centers[i] / parts[i].pixel_size
		add_child(parts[i])


func get_entries() -> Array:
	return _entries


func _make_key(key: String) -> Node3D:
	if not KEY_ICONS.has(key):
		return _make_text(key)
	var icon := Sprite3D.new()
	icon.texture = KEY_ICONS[key]
	icon.pixel_size = KEY_SIZE / icon.texture.get_height()
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return icon


func _make_text(text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = FONT_SIZE
	label.pixel_size = TEXT_PIXEL_SIZE
	label.outline_size = 24
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0, 0, 0, 0.8)
	return label


## 部品の横幅(メートル)。
func _width_of(part: Node3D) -> float:
	if part is Sprite3D:
		return part.texture.get_width() * part.pixel_size
	var font: Font = part.font if part.font else ThemeDB.fallback_font
	return font.get_string_size(part.text, HORIZONTAL_ALIGNMENT_LEFT, -1, part.font_size).x * part.pixel_size


## target の見えている見た目全体の一番上から、MARGIN だけ離れた真上に置く。
## 見た目がなければ、target の原点から DEFAULT_HEIGHT だけ上に置く。
func place_above(target: Node3D) -> void:
	var bounds: Variant = _visible_bounds(target)
	if bounds == null:
		global_position = target.global_position + Vector3.UP * DEFAULT_HEIGHT
		return
	var center: Vector3 = bounds.get_center()
	global_position = Vector3(center.x, bounds.end.y + MARGIN, center.z)
	global_basis = Basis.IDENTITY


## target の配下で見えている見た目を、ワールド座標でまとめて囲む箱。見た目がなければ null。
func _visible_bounds(target: Node3D) -> Variant:
	var bounds: Variant = null
	for mesh: MeshInstance3D in target.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if bounds == null else bounds.merge(box)
	return bounds
