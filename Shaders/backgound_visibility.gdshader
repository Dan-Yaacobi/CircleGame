shader_type canvas_item;

uniform vec2 circle_center; // in the background_sprite's local UV space, 0-1
uniform float radius_px;    // radius in pixels
uniform vec2 texture_size;  // size of the background_sprite in pixels
uniform float edge_softness : hint_range(0.0, 50.0) = 2.0;

void fragment() {
    vec2 pixel_pos = UV * texture_size;
    vec2 center_pixel = circle_center * texture_size;
    float dist = length(pixel_pos - center_pixel);

    float alpha = 1.0 - smoothstep(radius_px - edge_softness, radius_px + edge_softness, dist);

    COLOR = texture(TEXTURE, UV);
    COLOR.a *= alpha;
}