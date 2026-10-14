shader_type spatial;
render_mode cull_back;
// Mặt đất thử nghiệm: ô cỏ hai tông + con đường đất, không cần ảnh. Sau này thay bằng ảnh bản đồ vẽ tay.

uniform vec4 col_a : source_color = vec4(0.3, 0.45, 0.28, 1.0);
uniform vec4 col_b : source_color = vec4(0.33, 0.5, 0.3, 1.0);
uniform vec4 path_col : source_color = vec4(0.62, 0.53, 0.38, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = floor(wpos.xz);
	float chk = mod(g.x + g.y, 2.0);
	vec3 c = mix(col_a.rgb, col_b.rgb, chk);
	float h = fract(sin(dot(g, vec2(12.9898, 78.233))) * 43758.5453);
	c *= 0.94 + 0.12 * h;
	float p = smoothstep(1.7, 1.2, abs(wpos.x + sin(wpos.z * 0.22) * 1.6));
	c = mix(c, path_col.rgb * (0.96 + 0.08 * h), p);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
