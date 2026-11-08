// 戸口の覗き窓。対になるドアの裏から撮った景色を、画面の同じ位置にそのまま貼る。
// 窓の形に切り抜かれて見えるので、戸口の向こうに別の場所が続いているように見える。
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

uniform sampler2D view_texture : source_color, filter_linear;

void fragment() {
	ALBEDO = texture(view_texture, SCREEN_UV).rgb;
}
