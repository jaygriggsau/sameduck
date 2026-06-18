shader_type spatial;
// Full-screen depth-edge outline (a "Borderlands" ink pass).
// Reconstructs view-space depth from the depth buffer and draws dark lines
// where depth changes sharply — i.e. object silhouettes and the seams between
// overlapping body parts. Composited over the rendered scene colour.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// Draws only the ink lines (transparent elsewhere) so the scene colour below is
// left untouched — avoids the gamma round-trip of recompositing the screen.
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

uniform float thickness : hint_range(0.5, 4.0) = 1.3;
uniform float sensitivity : hint_range(50.0, 4000.0) = 900.0;
uniform float edge_low : hint_range(0.0, 1.0) = 0.2;
uniform float edge_high : hint_range(0.0, 1.0) = 0.9;
uniform vec3 line_color : source_color = vec3(0.04, 0.04, 0.06);

void vertex() {
	// Cover the whole screen regardless of camera transform.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// Convention-agnostic edge detect on the raw depth buffer: silhouettes and
	// the seams between overlapping parts are sharp discontinuities, while the
	// ground varies smoothly. Works the same whether depth is reverse-Z or not.
	vec2 px = thickness / VIEWPORT_SIZE;
	float c = texture(depth_tex, SCREEN_UV).r;
	float l = texture(depth_tex, SCREEN_UV + vec2(-px.x, 0.0)).r;
	float r = texture(depth_tex, SCREEN_UV + vec2(px.x, 0.0)).r;
	float u = texture(depth_tex, SCREEN_UV + vec2(0.0, -px.y)).r;
	float dn = texture(depth_tex, SCREEN_UV + vec2(0.0, px.y)).r;

	float grad = abs(l - r) + abs(u - dn);
	float lap = abs(4.0 * c - l - r - u - dn);
	float edge = (grad + lap) * sensitivity;
	float line = smoothstep(edge_low, edge_high, clamp(edge, 0.0, 1.0));

	ALBEDO = line_color;
	ALPHA = line;
}
