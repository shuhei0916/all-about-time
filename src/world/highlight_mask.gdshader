shader_type spatial;
// 狙っている物の形の所に、印(ステンシル)だけを付ける。色は足さない(足し算で 0 を足す)。
// 縁(highlight_outline.gdshader)は、全部の部品に印を付け終えてから描く(render_priority で順番を決める)。
render_mode unshaded, blend_add, depth_draw_never;
stencil_mode write, compare_always, 64;

void fragment() {
	ALBEDO = vec3(0.0);
}
