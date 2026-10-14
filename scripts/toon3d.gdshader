shader_type spatial;
render_mode cull_back;
// Tô toon: một vạch sáng/tối cứng (kiểu tranh cel) + chút viền sáng ở mép. Bóng tối lấy từ ánh sáng môi trường nên đổi màu môi trường là đổi màu vùng tối.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float cut : hint_range(0.0, 1.0) = 0.38;   // ngưỡng giữa vùng sáng và vùng tối
uniform float rim_strength : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = albedo.rgb + vec3(rim * rim_strength);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float d = dot(NORMAL, LIGHT);
	float lit = smoothstep(cut - 0.02, cut + 0.02, d) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;   // LIGHT_COLOR đã nhân sẵn PI
}
