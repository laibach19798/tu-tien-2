shader_type spatial;
render_mode cull_back;
// Tô toon: một vạch sáng/tối cứng (kiểu tranh cel) + chút viền sáng ở mép. Bóng tối lấy từ ánh sáng môi trường nên đổi màu môi trường là đổi màu vùng tối.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float cut : hint_range(0.0, 1.0) = 0.38;   // ngưỡng giữa vùng sáng và vùng tối
uniform float rim_strength : hint_range(0.0, 1.0) = 0.1;
uniform float shine : hint_range(0.0, 1.0) = 0.0;   // vòng sáng trên tóc (angel ring); 0 = tắt

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	float ring = 0.0;
	if (shine > 0.0) {
		float h = dot(normalize(NORMAL), normalize(vec3(0.0, 0.5, 0.86)));
		ring = smoothstep(0.84, 0.88, h) * (1.0 - smoothstep(0.93, 0.97, h));
	}
	ALBEDO = albedo.rgb + vec3(rim * rim_strength) + (vec3(1.0) - albedo.rgb) * ring * shine;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float d = dot(NORMAL, LIGHT);
	float lit = smoothstep(cut - 0.02, cut + 0.02, d) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;   // LIGHT_COLOR đã nhân sẵn PI
}
