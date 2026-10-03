extends SceneTree
## 文字の地図 src/world/city/city_map.txt から、街のシーン src/world/city/city.tscn を作り直す。
##
##   godot --headless -s tools/bake_city.gd
##
## 地図が決まり(CityPlan.problems)に合わなければ、問題を表示して何も書かない。
## city.tscn は毎回作り直すので、エディタでの手直しは消える。手で置く物は別のシーンに置く。

const MAP := "res://src/world/city/city_map.txt"
const OUT := "res://src/world/city/city.tscn"


func _initialize() -> void:
	var plan := CityPlan.new(FileAccess.get_file_as_string(MAP))
	var problems := plan.problems()
	if not problems.is_empty():
		for problem in problems:
			printerr(problem)
		quit(1)
		return
	var city := CityBuilder.build(plan)
	var scene := PackedScene.new()
	var error := scene.pack(city)
	if error == OK:
		error = ResourceSaver.save(scene, OUT)
	print("%s を書いた(建物 %d、街灯 %d)" % [OUT, city.get_node("Buildings").get_child_count(), city.get_node("Lamps").get_child_count()] if error == OK else "書けなかった: %s" % error_string(error))
	city.free()
	quit(0 if error == OK else 1)
