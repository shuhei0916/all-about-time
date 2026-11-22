extends RefCounted
## 電話ボックスの電話の見た目の確認用(tools/screenshot.sh と組み合わせる)。
## 101 の箱の中で電話を向き、ダイヤルし始めて 2 と 0 を押したところを映す。照準の下の案内も出る。


func run(scene: Node) -> void:
	var game := scene as Game
	var booth: PhoneBooth = game.phone_network.get_node("Booth101")
	game.player.respawn_at(booth.global_position + Vector3(0, 0.03, 0))
	game.player.rotation.y = booth.rotation.y
	game.player.camera.rotation_degrees.x = -12.0
	await scene.get_tree().physics_frame
	await scene.get_tree().physics_frame
	booth.car.phone.interact()
	game.press_phone_digit(2)
	game.press_phone_digit(0)
