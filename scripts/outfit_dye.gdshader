shader_type canvas_item;
// Nhuộm áo: đổi màu các pixel vải xanh của áo gốc (hue 170°-270°) sang màu thuốc nhuộm.
// Da, đai, giày và các màu khác giữ nguyên. Cùng quy tắc với tools/make_recolors.ps1.

uniform float hue = 355.0;       // màu đích, độ (0..360)
uniform float sat_mul = 1.0;
uniform float val_mul = 1.0;
uniform float val_add = 0.0;

vec3 rgb2hsv(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float h = 0.0;
	if (d > 0.0) {
		if (mx == c.r) h = mod((c.g - c.b) / d, 6.0);
		else if (mx == c.g) h = (c.b - c.r) / d + 2.0;
		else h = (c.r - c.g) / d + 4.0;
		h *= 60.0;
		if (h < 0.0) h += 360.0;
	}
	return vec3(h, mx <= 0.0 ? 0.0 : d / mx, mx);
}

vec3 hsv2rgb(vec3 c) {
	float ch = c.z * c.y;
	float x = ch * (1.0 - abs(mod(c.x / 60.0, 2.0) - 1.0));
	float m = c.z - ch;
	vec3 r = vec3(0.0);
	if (c.x < 60.0) r = vec3(ch, x, 0.0);
	else if (c.x < 120.0) r = vec3(x, ch, 0.0);
	else if (c.x < 180.0) r = vec3(0.0, ch, x);
	else if (c.x < 240.0) r = vec3(0.0, x, ch);
	else if (c.x < 300.0) r = vec3(x, 0.0, ch);
	else r = vec3(ch, 0.0, x);
	return r + vec3(m);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(c.rgb);
	if (c.a > 0.0 && hsv.x >= 170.0 && hsv.x <= 270.0 && hsv.y > 0.12) {
		hsv.x = hue;
		hsv.y = min(1.0, hsv.y * sat_mul);
		hsv.z = min(1.0, hsv.z * val_mul + val_add);
		c.rgb = hsv2rgb(hsv);
	}
	COLOR = c;
}
