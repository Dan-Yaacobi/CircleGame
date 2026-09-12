shader_type canvas_item;

// Ticket boundary — stays fixed regardless of how the artwork is framed below.
uniform vec2 circle_center;  // in the sprite's own UV space, 0-1
uniform float radius_px;     // radius in pixels (matches ScratchCircle.curr_radius)
uniform vec2 texture_size;   // size of the background texture in pixels
uniform float edge_softness : hint_range(0.0, 50.0) = 2.0;

// Artwork framing — how the image sits inside that fixed boundary.
uniform vec2 image_offset = vec2(0.0, 0.0);  // pan, in UV units
uniform float image_zoom : hint_range(0.05, 10.0) = 1.0;  // >1 zooms in
uniform float image_rotation = 0.0;  // radians

void fragment() {
	vec2 pixel_pos = UV * texture_size;
	vec2 center_pixel = circle_center * texture_size;
	float dist = length(pixel_pos - center_pixel);
	float alpha = 1.0 - smoothstep(radius_px - edge_softness, radius_px + edge_softness, dist);

	vec2 uv = UV - 0.5;
	uv /= image_zoom;
	float s = sin(image_rotation);
	float c = cos(image_rotation);
	uv = mat2(vec2(c, s), vec2(-s, c)) * uv;
	uv += 0.5 + image_offset;

	COLOR = texture(TEXTURE, uv);
	COLOR.a *= alpha;
}
