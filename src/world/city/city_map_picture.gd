class_name CityMapPicture
extends RefCounted
## 文字の地図(CityPlan)から、上から見た街の絵を描く。電話ボックスの中の、行先を選ぶ地図に使う。
## 絵の左上が地図の左上のマスで、右が +X、下が +Z。

const ROAD_COLOR := Color(0.2, 0.2, 0.2)
const BLOCK_COLOR := Color(0.6, 0.4, 0.2)
const PLAZA_COLOR := Color(0.4, 0.6, 0.4)
const ALLEY_COLOR := Color(0.4, 0.4, 0.4)
const SITE_COLOR := Color(0.8, 0.8, 0.6)
const OUTSIDE_COLOR := Color(0.0, 0.0, 0.0)


## 1マスを px_per_cell 画素四方で塗った絵。
static func render(plan: CityPlan, px_per_cell: int) -> Image:
	var image := Image.create(plan.size.x * px_per_cell, plan.size.y * px_per_cell, false, Image.FORMAT_RGBA8)
	image.fill(OUTSIDE_COLOR)
	for z in plan.size.y:
		for x in plan.size.x:
			var color := _color_at(plan, Vector2i(x, z))
			image.fill_rect(Rect2i(x * px_per_cell, z * px_per_cell, px_per_cell, px_per_cell), color)
	for area in plan.areas():
		var color: Color = {
			CityPlan.Area.Kind.BLOCK: BLOCK_COLOR,
			CityPlan.Area.Kind.PLAZA: PLAZA_COLOR,
			CityPlan.Area.Kind.ALLEY: ALLEY_COLOR,
			CityPlan.Area.Kind.SITE: SITE_COLOR,
		}[area.kind]
		var cells := area.cells
		image.fill_rect(Rect2i(cells.position * px_per_cell, cells.size * px_per_cell), color)
	return image


## 街の位置 world(メートル)の、絵の上の位置(左上が 0、右下が 1)。
static func uv_of(plan: CityPlan, world: Vector3) -> Vector2:
	var whole := plan.rect_of(Rect2i(Vector2i.ZERO, plan.size))
	return (Vector2(world.x, world.z) - whole.position) / whole.size


## 区画などのまとまりに入らないマス(道路に覆われたマスと街の外)の色。
static func _color_at(plan: CityPlan, at: Vector2i) -> Color:
	if plan.cell(at) == " ":
		return OUTSIDE_COLOR
	return ROAD_COLOR if plan.is_covered_by_road(at) else OUTSIDE_COLOR
