shader_type spatial;
// 狙っている物の上に重ねて描き、輪郭に縁取りを付ける。元の見た目は変えない。
// 見た目を少し膨らませた形の裏側だけを描くので、元の見た目からはみ出した縁だけが見える(反転した殻)。
render_mode unshaded, cull_front;

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
}
