shader_type canvas_item;
// Viền sáng nhịp thở + ánh sáng ngấm vào áo. Gắn lên lớp Clothes của bộ có "aura".

uniform vec4 glow_color : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float pulse_speed = 2.2;
uniform float outline_width = 1.0;
uniform float inner_glow = 0.18;
uniform vec3 boost = vec3(1.0);   // bù lại màu đêm của CanvasModulate để viền không bị tối theo

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
	float near = 0.0;
	near = max(near, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	near = max(near, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	near = max(near, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	near = max(near, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	near = max(near, texture(TEXTURE, UV + px).a);
	near = max(near, texture(TEXTURE, UV - px).a);
	near = max(near, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	near = max(near, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	float edge = (1.0 - c.a) * near;
	float pulse = 0.65 + 0.35 * sin(TIME * pulse_speed);
	vec3 glow = glow_color.rgb * boost;
	vec3 lit = c.rgb + glow * inner_glow * pulse * c.a;
	COLOR.rgb = mix(lit, glow, edge);
	COLOR.a = c.a + edge * glow_color.a * pulse;
}
