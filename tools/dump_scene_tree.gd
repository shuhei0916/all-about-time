extends SceneTree
## シーンをヘッドレスで起動し、入力シナリオを流したあとのシーンツリーを出力する動作確認ツール。
## スクリーンショットを使わず、ノード構成・配置・表示状態をテキストで確認するために使う。
##
## 使い方（-- 以降がこのスクリプトへの引数）:
##   godot --headless --script res://tools/dump_scene_tree.gd -- [options]
##
## options:
##   --scene=<res://...>     起動するシーン（既定: project の main_scene）
##   --do=<steps>            入力シナリオ。";" 区切りで順に実行する
##                             key:SPACE        キーを押して離す（Key 定数名から KEY_ を除いたもの）
##                             action:rotate_piece  InputMap のアクションを押して離す
##                             move:400,300     マウス移動（ビューポート座標）
##                             click:400,300    左クリック（rclick: で右クリック）
##                             mdrag:400,300,500,250  中ボタンを押したまま 1点目→2点目へドラッグ
##                             moveto:WorldMapView/@Node2D@5  ノードの画面位置へマウス移動
##                             clickon:<NodePath>  ノードの画面位置を左クリック
##                             wait:10          指定フレーム待つ
##                             call:World/get_chunk_hexes  ノードのメソッドを呼び結果を表示
##                             script:res://tools/scenarios/x.gd  シナリオの run(scene) を実行（await 可）
##                             shot:C:/path/to/out.png  画面を PNG に保存（描画ありで起動したときだけ。screenshot.sh 参照）
##   --root=<NodePath>       出力するサブツリーの起点（シーンルートからの相対パス）
##   --depth=<n>             出力する最大深さ（既定: 無制限）
##   --props=<a,b,...>       追加で出力するプロパティ（そのプロパティを持つノードのみ）
##   --frames=<n>            起動後、シナリオ開始前に待つフレーム数（既定: 2）

var _args := {}
var _extra_props: PackedStringArray = []


func _initialize() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	_extra_props = String(_args.get("props", "")).split(",", false)
	_run.call_deferred()


func _run() -> void:
	var scene_path: String = _args.get(
		"scene", ProjectSettings.get_setting("application/run/main_scene")
	)
	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("シーンを読み込めません: %s" % scene_path)
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene

	for i in int(_args.get("frames", "2")):
		await process_frame

	var steps := String(_args.get("do", "")).split(";", false)
	for step in steps:
		await _run_step(step.strip_edges())

	# 入力処理の反映（_draw 予約・call_deferred 等）を待つ
	await process_frame

	var target: Node = scene
	if _args.has("root"):
		target = scene.get_node_or_null(NodePath(_args["root"]))
		if target == null:
			printerr("ノードが見つかりません: %s" % _args["root"])
			quit(1)
			return

	print("=== scene tree: %s (root=%s) ===" % [scene_path, scene.get_path_to(target)])
	_dump(target, 0, int(_args.get("depth", "-1")))
	quit(0)


func _run_step(step: String) -> void:
	var kind := step.get_slice(":", 0)
	var value := step.substr(kind.length() + 1)
	match kind:
		"key":
			_send_key(value)
		"action":
			_send_action(value)
		"move":
			_send_mouse_motion(_parse_vec(value))
		"click":
			_send_click(_parse_vec(value), MOUSE_BUTTON_LEFT)
		"rclick":
			_send_click(_parse_vec(value), MOUSE_BUTTON_RIGHT)
		"mdrag":
			var nums = value.split(",")
			_send_drag(
				Vector2(float(nums[0]), float(nums[1])),
				Vector2(float(nums[2]), float(nums[3])),
				MOUSE_BUTTON_MIDDLE
			)
		"moveto":
			_send_mouse_motion(_screen_pos_of(value))
		"clickon":
			_send_click(_screen_pos_of(value), MOUSE_BUTTON_LEFT)
		"wait":
			for i in int(value):
				await process_frame
			return
		"call":
			_call_method(value)
		"script":
			await _run_scenario(value)
		"shot":
			await _save_screenshot(value)
		_:
			printerr("不明なステップ: %s" % step)
	print("[step] %s" % step)
	await process_frame


func _send_key(key_name: String) -> void:
	var keycode := OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		printerr("不明なキー: %s" % key_name)
		return
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()


func _send_action(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()


func _send_mouse_motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _send_click(pos: Vector2, button: MouseButton) -> void:
	_send_mouse_motion(pos)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.position = pos
		ev.global_position = pos
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()


func _send_drag(from: Vector2, to: Vector2, button: MouseButton) -> void:
	_send_mouse_motion(from)
	_send_mouse_button(from, button, true)
	var ev := InputEventMouseMotion.new()
	ev.position = to
	ev.global_position = to
	ev.relative = to - from
	ev.button_mask = MOUSE_BUTTON_MASK_MIDDLE if button == MOUSE_BUTTON_MIDDLE else 0
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	_send_mouse_button(to, button, false)


func _send_mouse_button(pos: Vector2, button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.position = pos
	ev.global_position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## 画面を PNG に保存する。--headless では描画されないので、screenshot.sh から描画ありで起動する
func _save_screenshot(path: String) -> void:
	# 描画が画面に反映されるまで数フレーム待つ
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("画面を取得できません（--headless では撮れない）")
		return
	var err := image.save_png(path)
	print("screenshot: %s (%s)" % [path, "ok" if err == OK else error_string(err)])


## カメラ等のキャンバス変換を含めた、ノード原点のビューポート座標
func _screen_pos_of(path: String) -> Vector2:
	var node := current_scene.get_node_or_null(NodePath(path))
	if not node is CanvasItem:
		printerr("CanvasItem が見つかりません: %s" % path)
		return Vector2.ZERO
	return node.get_global_transform_with_canvas().origin


## 引数付きの呼び出しや複数フレームにわたる観察など、ステップで書けない操作を行う
func _run_scenario(path: String) -> void:
	var scenario = load(path)
	if scenario == null or not scenario.new().has_method("run"):
		printerr("シナリオを実行できません（run(scene) が必要）: %s" % path)
		return
	await scenario.new().run(current_scene)


func _call_method(value: String) -> void:
	var node_path := value.get_base_dir()
	var method := value.get_file()
	var node := (
		current_scene.get_node_or_null(NodePath(node_path)) if node_path != "" else current_scene
	)
	if node == null or not node.has_method(method):
		printerr("呼び出せません: %s" % value)
		return
	print("[call] %s -> %s" % [value, _fmt(node.call(method))])


func _dump(node: Node, depth: int, max_depth: int) -> void:
	if max_depth >= 0 and depth > max_depth:
		return
	print("%s%s (%s)%s" % ["  ".repeat(depth), node.name, _class_label(node), _describe(node)])
	for child in node.get_children():
		_dump(child, depth + 1, max_depth)


func _class_label(node: Node) -> String:
	var script: Script = node.get_script()
	if script and script.get_global_name() != &"":
		return "%s:%s" % [script.get_global_name(), node.get_class()]
	return node.get_class()


## 既定値と異なる主要プロパティだけを出し、出力を読みやすく保つ
func _describe(node: Node) -> String:
	var parts: PackedStringArray = []
	if node is Node2D:
		if node.position != Vector2.ZERO:
			parts.append("pos=%s" % _fmt(node.position))
		if node.rotation != 0.0:
			parts.append("rot=%.0f°" % rad_to_deg(node.rotation))
		if node.scale != Vector2.ONE:
			parts.append("scale=%s" % _fmt(node.scale))
	elif node is Node3D:
		if not node.position.is_zero_approx():
			parts.append("pos=%s" % _fmt(node.position))
		if not node.rotation.is_zero_approx():
			parts.append("rot=%s" % _fmt(node.rotation_degrees))
		if not node.scale.is_equal_approx(Vector3.ONE):
			parts.append("scale=%s" % _fmt(node.scale))
		if not node.visible:
			parts.append("HIDDEN")
	elif node is Control:
		parts.append("rect=%s+%s" % [_fmt(node.position), _fmt(node.size)])
		if node is Label or node is Button:
			if node.text != "":
				parts.append("text=%s" % JSON.stringify(node.text))
	if node is CanvasItem:
		if not node.visible:
			parts.append("HIDDEN")
		elif not node.is_visible_in_tree():
			parts.append("hidden_by_parent")
		if node.modulate != Color.WHITE:
			parts.append("modulate=%s" % _fmt(node.modulate))
		if node.self_modulate != Color.WHITE:
			parts.append("self_modulate=%s" % _fmt(node.self_modulate))
		if node.z_index != 0:
			parts.append("z=%d" % node.z_index)
	if node is Polygon2D or node is Line2D:
		parts.append("color=%s" % _fmt(node.color if node is Polygon2D else node.default_color))
	if node is CanvasLayer and not node.visible:
		parts.append("HIDDEN")
	for prop in _extra_props:
		if prop in node:
			parts.append("%s=%s" % [prop, _fmt(node.get(prop))])
	return "" if parts.is_empty() else "  " + " ".join(parts)


func _fmt(v) -> String:
	if v is Vector2:
		return "(%.1f,%.1f)" % [v.x, v.y]
	if v is Vector3:
		return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]
	if v is Color:
		return "#" + v.to_html(v.a < 1.0)
	if v is Array:
		return "[" + ", ".join(v.map(func(e): return _fmt(e))) + "]"
	return str(v)


func _parse_vec(s: String) -> Vector2:
	var xy := s.split(",")
	return Vector2(float(xy[0]), float(xy[1]))


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var result := {}
	for a in raw:
		if a.begins_with("--") and "=" in a:
			var key := a.substr(2, a.find("=") - 2)
			result[key] = a.substr(a.find("=") + 1)
	return result
