shader_type spatial;
// 狙っている物の輪郭の外側に縁を描く。highlight_mask.gdshader が物の形の所に印(ステンシル)を付けた後に描き、
// 印のない所にだけ描くので、部品がいくつあっても全体の輪郭だけに縁が付く(テンキーの1つ1つには付かない)。
render_mode unshaded, depth_draw_never, cull_back;
stencil_mode read, compare_not_equal, 64;

uniform vec4 color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
// 縁の太さ。カメラからの距離1メートルあたりの膨らみ(メートル)なので、遠くても近くても画面の上でほぼ同じ太さになる。
uniform float width_per_meter = 0.008;

void vertex() {
	// 原点から外へ膨らませる。面ごとに法線が分かれた箱でも、角で縁が割れない。
	vec3 outward = length(VERTEX) > 0.0001 ? normalize(VERTEX) : NORMAL;
	float depth = max(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z, 0.1);
	VERTEX += outward * width_per_meter * depth;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = 1.0;
}
