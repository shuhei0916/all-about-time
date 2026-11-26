extends RefCounted
## 電話ボックスの見た目の確認用(tools/screenshot.sh と組み合わせる)。空き区画 L の 101 の箱を使う。
## 環境変数 PHONE_VIEW で映すものを選ぶ。
##   outside  箱の正面に立って箱を見る。PHONE_BOOTH で箱の番号を選べる(既定 101)
##   inside   箱の中に立って、行先の地図を見る
##   ride     箱の中で 204 をダイヤルし、PHONE_WAIT 秒(既定 1)待つ。PHONE_CAM=outside なら、外のカメラから出発の箱を、
##            PHONE_CAM=arrive なら、外のカメラから行先の箱(204)を映す
## PHONE_PITCH で見上げ・見下ろしの角度(度、上が正)を変えられる。


func run(scene: Node) -> void:
	var game := scene as Game
	var player := game.player
	var network := game.phone_network
	var view := OS.get_environment("PHONE_VIEW")
	var number := OS.get_environment("PHONE_BOOTH") if view == "outside" and OS.has_environment("PHONE_BOOTH") else "101"
	var booth: PhoneBooth = network.get_node("Booth" + number)
	var pitch := float(OS.get_environment("PHONE_PITCH")) if OS.has_environment("PHONE_PITCH") else 0.0
	if view == "outside":
		player.respawn_at(booth.global_transform * Vector3(0, 0.1, 3))
		player.rotation.y = booth.rotation.y
		player.camera.rotation_degrees.x = pitch
		return
	player.respawn_at(booth.global_position + Vector3(0, 0.03, 0.15))
	player.rotation.y = booth.rotation.y + PI / 2.0
	player.camera.rotation_degrees.x = pitch
	await scene.get_tree().physics_frame
	await scene.get_tree().physics_frame
	if view == "inside":
		return
	booth.car.phone.interact()
	for digit in [2, 0, 4]:
		booth.car.phone.press(digit)
	var cam := OS.get_environment("PHONE_CAM")
	if cam != "":
		var target: PhoneBooth = booth if cam == "outside" else network.get_node("Booth204")
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.global_position = target.global_transform * Vector3(0, 1.8, 5)
		camera.look_at(target.global_position + Vector3(0, 1.5, 0))
		camera.cull_mask &= ~PhoneNetwork.BLIND_LAYER
		camera.current = true
	var wait := float(OS.get_environment("PHONE_WAIT")) if OS.has_environment("PHONE_WAIT") else 1.0
	await scene.get_tree().create_timer(wait).timeout
	print("ride phase=%s height=%.2f rider=%s" % [
		PhoneRide.Phase.keys()[network.ride.phase] if network.ride else "none",
		network.ride.height() if network.ride else 0.0, player.global_position])
