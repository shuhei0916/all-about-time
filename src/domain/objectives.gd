class_name Objectives
extends RefCounted
## チュートリアル目標の並びを管理する。完了すると順に次へ進む。

var _titles: Array[String]
var _index := 0


func _init(titles: Array[String]) -> void:
	_titles = titles


## 現在の目標の文言を返す。全て完了していれば空文字。
func current() -> String:
	if is_all_completed():
		return ""
	return _titles[_index]


## 全ての目標を完了したか。
func is_all_completed() -> bool:
	return _index >= _titles.size()


## 現在の目標を完了し、次の目標へ進める。
func complete() -> void:
	_index += 1
