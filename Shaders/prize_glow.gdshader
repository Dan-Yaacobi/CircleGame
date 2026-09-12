shader_type canvas_item;

// --- Sprite-sheet awareness -------------------------------------------------
// Prize sprites share one atlas (Prizes.png) and only show one frame via
// hframes/vframes. Godot's built-in UV for a framed Sprite2D still spans the
// WHOLE atlas (not just the visible frame), so without this the silhouette
// scan below would read pixels from neighboring icons. These three are set
// from script (Prize._update_glow_frame_uniforms) to describe just the
// current frame's own rectangle, in both UV and pixel terms.
uniform vec2 frame_uv_origin = vec2(0.0);          // this frame's top-left, in atlas UV space
uniform vec2 frame_uv_size = vec2(1.0);            // this frame's size, in atlas UV space
uniform vec2 frame_pixel_size = vec2(32.0, 32.0);  // this frame's size, in actual pixels

// --- Glow knobs --------------------------------------------------------------
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float outline_width : hint_range(0.0, 16.0) = 2.0;   // px, crisp core ring thickness
uniform float glow_spread : hint_range(0.0, 32.0) = 6.0;     // px, extra soft halo past the ring
uniform float glow_softness : hint_range(0.01, 1.0) = 0.5;   // 0 = hard ring, 1 = soft cloud
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;   // brightness of the glow
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;     // cycles/sec, 0 disables pulsing
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.35;    // how much the pulse changes intensity
uniform int ring_samples : hint_range(4, 32) = 10;           // angular resolution of the silhouette scan (cost knob)
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.5;  // alpha above which a texel counts as "sprite"

const float TAU_C = 6.28318530718;
const int RADIUS_STEPS = 4;

// Reads the sprite's alpha at a point in this frame's own local UV (0..1),
// clamped so it can never read past this frame's edge into a neighbor.
float sample_alpha(vec2 local_uv) {
	vec2 clamped = clamp(local_uv, vec2(0.0), vec2(1.0));
	return texture(TEXTURE, frame_uv_origin + clamped * frame_uv_size).a;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 result = base;

	if (base.a < 0.99) {
		vec2 local_uv = (UV - frame_uv_origin) / frame_uv_size;
		float max_reach_px = max(outline_width + glow_spread, 0.001);
		vec2 px_to_uv = 1.0 / max(frame_pixel_size, vec2(1.0));

		// Coarse radial search for the nearest opaque pixel of the actual
		// artwork (not the frame's bounds), so padding inside the frame
		// doesn't push the glow out to the frame's edge.
		float hit_radius = max_reach_px + 1.0;  // sentinel: nothing found yet
		for (int r = 1; r <= RADIUS_STEPS; r++) {
			float dist_px = max_reach_px * float(r) / float(RADIUS_STEPS);
			if (dist_px < hit_radius) {
				for (int i = 0; i < ring_samples; i++) {
					float ang = TAU_C * float(i) / float(ring_samples);
					vec2 offset = vec2(cos(ang), sin(ang)) * dist_px * px_to_uv;
					if (sample_alpha(local_uv + offset) > alpha_threshold) {
						hit_radius = min(hit_radius, dist_px);
					}
				}
			}
		}

		float t = 1.0 - clamp(hit_radius / max_reach_px, 0.0, 1.0);
		float pulse = 1.0 + sin(TIME * pulse_speed * TAU_C) * 0.5 * pulse_amount;
		float glow_alpha = pow(t, mix(4.0, 0.4, glow_softness)) * glow_intensity * pulse;
		glow_alpha *= (1.0 - base.a);
		glow_alpha = clamp(glow_alpha, 0.0, 1.0);

		vec4 glow = vec4(glow_color.rgb, glow_alpha * glow_color.a);
		result = mix(glow, base, base.a);
	}

	COLOR = result;
}
