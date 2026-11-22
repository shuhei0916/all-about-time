class_name PhoneShaft
extends Node3D
## 電話ボックスで移る間に下る、地下の縦穴。街から見えない深い所に置く。
## 内部(PhoneBoothCar)はその場にとどまり、壁が下った深さだけ上へ流れて、下っているように見せる。
## 壁の模様は PATTERN_LENGTH ごとに繰り返し、上下に並べた写しでつなぎ目を隠す。

## 壁の模様の1回分の長さ(メートル)。
const PATTERN_LENGTH := 24.0

## 下った深さ(メートル)。壁はこれだけ上へ流れる。
var depth := 0.0:
	set(value):
		depth = value
		if is_node_ready():
			walls.position.y = fposmod(depth, PATTERN_LENGTH)

@onready var car: PhoneBoothCar = $Car
@onready var walls: Node3D = $Walls
