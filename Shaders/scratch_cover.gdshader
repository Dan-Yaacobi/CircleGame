shader_type canvas_item;

// TEXTURE is the runtime scratch mask: r=1 means still covered, r=0 means revealed.
uniform vec4 cover_color : source_color = vec4(0.55, 0.57, 0.62, 1.0);
uniform float edge_softness : hint_range(0.0, 0.1) = 0.015;

void fragment() {
	float dist = length(UV - vec2(0.5));
	float boundary_alpha = 1.0 - smoothstep(0.5 - edge_softness, 0.5, dist);
	float scratch_alpha = texture(TEXTURE, UV).r;

	COLOR = cover_color;
	COLOR.a *= boundary_alpha * scratch_alpha;
}
