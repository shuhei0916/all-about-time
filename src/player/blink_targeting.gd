class_name BlinkTargeting
extends RefCounted
## 照準の近くにいる候補から、背後へ跳ぶ相手を1人選ぶ。物理に頼らない判断だけを受け持つ。
## 照準をぴったり合わせなくてもよいよう、視線から一定の角度以内を許す。
## 角度で決めると、近い相手にも遠い相手にも、画面の上ではほぼ同じ広さの許容範囲になる。


## eye から forward の向きに見て、max_angle_degrees 以内のずれで max_range 以内にいる候補のうち、
## 照準に一番近い(ずれが同じなら距離が近い)候補の番号を返す。いなければ -1。
static func choose(eye: Vector3, forward: Vector3, candidates: Array[Vector3], max_angle_degrees: float, max_range: float) -> int:
	var best := -1
	var best_angle := INF
	var best_distance := INF
	for i in candidates.size():
		var to_candidate := candidates[i] - eye
		var distance := to_candidate.length()
		if distance > max_range or is_zero_approx(distance):
			continue
		var angle := rad_to_deg(forward.angle_to(to_candidate))
		if angle > max_angle_degrees:
			continue
		if angle < best_angle - 0.001 or (absf(angle - best_angle) <= 0.001 and distance < best_distance):
			best = i
			best_angle = angle
			best_distance = distance
	return best
