shader_type spatial;
render_mode cull_front, unshaded;
// Viền mực: vẽ lại chính khối đó phình ra một chút, chỉ giữ mặt trong (cull_front) nên chỉ lộ ra phần rìa.
// radial = true cho khối có cạnh cứng (hộp, trụ): đẩy theo hướng từ tâm khối để viền không bị đứt ở góc.

uniform vec4 ink : source_color = vec4(0.09, 0.06, 0.11, 1.0);
uniform float width = 0.02;
uniform bool radial = false;

void vertex() {
	if (radial) {
		VERTEX += normalize(VERTEX + NORMAL * 0.0001) * width;
	} else {
		VERTEX += NORMAL * width;
	}
}

void fragment() {
	ALBEDO = ink.rgb;
}
