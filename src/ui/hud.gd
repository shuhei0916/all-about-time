class_name Hud
extends CanvasLayer
## 画面左上に現在の目標、右上に世界の時計とその下に残り寿命、左下に持ち物、右下に口座の残高、下中央に設計図の配置の案内、
## 照準のすぐ下に見ている物の操作の案内(キーの絵と文言)を表示する。
## 現金は物(札束)として持つので、数字では出さない。
## 死亡時と眠った時は画面を黒で覆い、明けていく。

const FADE_DURATION := 1.5
## 寿命の増減を示すラベルが出てから消えるまでの秒数。
const DELTA_DURATION := 1.2
## ラベルが流れ落ちる距離(ピクセル)。
const DELTA_RISE := 40.0
const DELTA_LOSS_COLOR := Color(1.0, 0.25, 0.25)
const DELTA_GAIN_COLOR := Color(0.35, 1.0, 0.45)
## 操作の案内を、画面の中央(照準)からどれだけ下に出すか(ピクセル)。
const PROMPT_OFFSET := 44.0
## 操作の案内のキーの絵の大きさと、文字の大きさ(ピクセル)。
const PROMPT_KEY_SIZE := 34.0
const PROMPT_FONT_SIZE := 22
## 操作の組と組の間(ピクセル)。
const PROMPT_ENTRY_GAP := 24
## 右上の時計の下に寿命を出すための、寿命ラベルをずらす量(ピクセル)。
const LIFESPAN_OFFSET := 40.0

var fade_overlay: ColorRect
var objective_label: Label
var clock_label: Label
var lifespan_label: Label
var inventory_label: Label
var placement_label: Label
var balance_label: Label
## 照準の下の操作の案内。キーの絵と文言を横に並べる。
var prompt_row: HBoxContainer
var _prompt_entries: Array = []
var _delta_container: VBoxContainer


func _init() -> void:
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade_overlay)

	objective_label = _make_label(Control.PRESET_TOP_LEFT)
	clock_label = _make_label(Control.PRESET_TOP_RIGHT)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lifespan_label = _make_label(Control.PRESET_TOP_RIGHT)
	lifespan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lifespan_label.offset_top += LIFESPAN_OFFSET
	lifespan_label.offset_bottom += LIFESPAN_OFFSET
	inventory_label = _make_label(Control.PRESET_BOTTOM_LEFT)
	inventory_label.add_theme_font_size_override("font_size", 22)
	balance_label = _make_label(Control.PRESET_BOTTOM_RIGHT)
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	placement_label = _make_label(Control.PRESET_CENTER_BOTTOM)
	placement_label.text = "左クリック: 建てる　右クリック: やめる"
	placement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placement_label.add_theme_font_size_override("font_size", 24)
	placement_label.visible = false

	prompt_row = HBoxContainer.new()
	prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_row.add_theme_constant_override("separation", 6)
	prompt_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	prompt_row.anchor_top = 0.5
	prompt_row.anchor_bottom = 0.5
	prompt_row.offset_top = PROMPT_OFFSET
	prompt_row.offset_bottom = PROMPT_OFFSET
	prompt_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_row.visible = false
	add_child(prompt_row)

	# 変化量のラベルは寿命ラベルの真下に、新しいものから順に積む。
	_delta_container = VBoxContainer.new()
	_delta_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_delta_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delta_container.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16
	)
	_delta_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_delta_container.position.y += 56 + LIFESPAN_OFFSET
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
	balance_label.text = "口座 %s" % Money.format(life.account.balance)


## 世界の時計(日にち、曜日、時刻)を出す。毎フレーム呼ぶ。
func show_clock(clock: WorldClock) -> void:
	clock_label.text = clock.to_display_string()


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


## 照準の下に、操作の案内を出す。entries はキーと文言の組 [キー, 文言] の並び。空なら消す。
## キーに絵があれば絵で、なければ文字で出す。キーが空の組は文言だけを出す。前と同じなら作り直さない。
func show_prompt(entries: Array) -> void:
	prompt_row.visible = not entries.is_empty()
	if entries == _prompt_entries:
		return
	_prompt_entries = entries.duplicate(true)
	for child in prompt_row.get_children():
		prompt_row.remove_child(child)
		child.queue_free()
	for i in entries.size():
		var key: String = entries[i][0]
		if i > 0:
			var gap := Control.new()
			gap.custom_minimum_size.x = PROMPT_ENTRY_GAP
			prompt_row.add_child(gap)
		if KeyIcons.ICONS.has(key):
			prompt_row.add_child(_make_key_icon(KeyIcons.ICONS[key]))
		elif not key.is_empty():
			prompt_row.add_child(_make_prompt_text("[%s]" % key))
		prompt_row.add_child(_make_prompt_text(entries[i][1]))


func get_prompt_entries() -> Array:
	return _prompt_entries if prompt_row.visible else []


func is_prompt_visible() -> bool:
	return prompt_row.visible


func _make_key_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * PROMPT_KEY_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _make_prompt_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", PROMPT_FONT_SIZE)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return label


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


## 画面を一度黒で覆い、時間をかけて明けさせる。死んだ時と眠った時に使う。
func fade_from_black() -> void:
	fade_overlay.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, FADE_DURATION)
