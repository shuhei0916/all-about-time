class_name Hud
extends CanvasLayer
## 画面左上に現在の目標、右上に残り寿命、左下に持ち物、下中央に設計図の配置の案内を表示する。
## 操作案内は画面ではなく対象物の側に出すため、ここでは扱わない。
## 死亡時は画面を黒で覆い、次の人生の開始とともに明けていく。

const FADE_DURATION := 1.5
## 寿命の増減を示すラベルが出てから消えるまでの秒数。
const DELTA_DURATION := 1.2
## ラベルが流れ落ちる距離(ピクセル)。
const DELTA_RISE := 40.0
const DELTA_LOSS_COLOR := Color(1.0, 0.25, 0.25)
const DELTA_GAIN_COLOR := Color(0.35, 1.0, 0.45)

var fade_overlay: ColorRect
var objective_label: Label
var lifespan_label: Label
var inventory_label: Label
var placement_label: Label
var _delta_container: VBoxContainer


func _init() -> void:
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade_overlay)

	objective_label = _make_label(Control.PRESET_TOP_LEFT)
	lifespan_label = _make_label(Control.PRESET_TOP_RIGHT)
	lifespan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inventory_label = _make_label(Control.PRESET_BOTTOM_LEFT)
	inventory_label.add_theme_font_size_override("font_size", 22)
	placement_label = _make_label(Control.PRESET_CENTER_BOTTOM)
	placement_label.text = "左クリック: 建てる　右クリック: やめる"
	placement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placement_label.add_theme_font_size_override("font_size", 24)
	placement_label.visible = false

	# 変化量のラベルは寿命ラベルの真下に、新しいものから順に積む。
	_delta_container = VBoxContainer.new()
	_delta_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_delta_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delta_container.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16
	)
	_delta_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_delta_container.position.y += 56
	add_child(_delta_container)


func _make_label(preset: Control.LayoutPreset) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 16)
	# 文字が入って幅が広がるとき、右寄せなら左へ、中央寄せなら両側へ伸びるようにする。
	# これがないと既定の右向きに伸びて、右上のラベルが画面外へはみ出す。
	label.grow_horizontal = _grow_direction_for(preset)
	# 下端に置くラベルは、行が増えた時に上へ伸びないと画面外へはみ出す。
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM]:
		label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.add_theme_font_size_override("font_size", 28)
	add_child(label)
	return label


func _grow_direction_for(preset: Control.LayoutPreset) -> Control.GrowDirection:
	match preset:
		Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_RIGHT:
			return Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER:
			return Control.GROW_DIRECTION_BOTH
		_:
			return Control.GROW_DIRECTION_END


## 人生の状態をラベルに反映する。毎フレーム呼ぶ。
func update_from(life: Life) -> void:
	objective_label.text = life.objectives.current()
	lifespan_label.text = life.lifespan.to_clock_string()
	_update_inventory(life.inventory)


func _update_inventory(inventory: Inventory) -> void:
	var items := inventory.items()
	inventory_label.visible = not items.is_empty()
	var lines: Array[String] = ["持ち物（数字キーで使う）"]
	for i in items.size():
		lines.append("%d: %s  %s" % [i + 1, items[i].name, items[i].effect_text()])
	inventory_label.text = "
".join(lines)


## 設計図の配置モード中の操作の案内を出す、または消す。
func show_placement_hint(shown: bool) -> void:
	placement_label.visible = shown


## 寿命の増減を示すラベルを出す。減少は赤、増加は緑で、流れ落ちながら消える。
func show_lifespan_delta(amount: float) -> void:
	if is_zero_approx(amount):
		return
	var label := Label.new()
	label.text = Lifespan.format_delta(amount)
	label.modulate = DELTA_LOSS_COLOR if amount < 0.0 else DELTA_GAIN_COLOR
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 32)
	_delta_container.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + DELTA_RISE, DELTA_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DELTA_DURATION)
	tween.chain().tween_callback(label.queue_free)


## 表示中の変化量ラベルを返す。
func get_delta_labels() -> Array[Label]:
	var labels: Array[Label] = []
	for child in _delta_container.get_children():
		if child is Label and not child.is_queued_for_deletion():
			labels.append(child)
	return labels


## 画面を一度黒で覆い、時間をかけて明けさせる。
func start_death_fade() -> void:
	fade_overlay.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, FADE_DURATION)
