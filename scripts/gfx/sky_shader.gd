class_name SkyShaderLib
extends RefCounted
## 커스텀 하늘 셰이더 — 태양 원반 · 달 · 별 · 구름층 · 지평선 헤이즈.
## ProceduralSkyMaterial 로는 낼 수 없는 발헤임 특유의 낮은 태양/붉은 지평선을 만든다.

const SKY := """
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.20, 0.40, 0.72);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.80, 0.84);
uniform vec3 ground_color : source_color = vec3(0.14, 0.15, 0.16);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.78);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float day_amount = 1.0;      // 0 밤 ~ 1 낮
uniform float dusk_amount = 0.0;     // 일출/일몰 강도
uniform float cloud_amount = 0.35;
uniform float cloud_speed = 0.004;
uniform float star_amount = 1.0;
uniform float horizon_sharp = 3.0;
uniform sampler2D cloud_tex : filter_linear, repeat_enable;

// 값 해시 (별 배치용)
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float star_field(vec3 dir) {
	vec3 g = floor(dir * 220.0);
	float h = hash13(g);
	if (h < 0.9975) return 0.0;
	vec3 c = (g + 0.5) / 220.0;
	float d = distance(normalize(c), dir);
	float tw = 0.65 + 0.35 * sin(TIME * (1.5 + h * 40.0) + h * 90.0);
	return smoothstep(0.0045, 0.0, d) * tw;
}

// 세 겹으로 흘러가는 구름. 밀도를 그대로 돌려줘서 두께 음영을 낼 수 있게 한다.
float clouds(vec3 dir) {
	if (dir.y < 0.02) return 0.0;
	vec2 uv = dir.xz / max(dir.y + 0.22, 0.06);
	float a = texture(cloud_tex, uv * 0.045 + vec2(TIME * cloud_speed, 0.0)).r;
	float b = texture(cloud_tex, uv * 0.105 - vec2(TIME * cloud_speed * 1.7,
		TIME * cloud_speed * 0.4)).r;
	float c2 = texture(cloud_tex, uv * 0.260 + vec2(TIME * cloud_speed * 2.6,
		-TIME * cloud_speed * 0.9)).r;
	float c = a * 0.55 + b * 0.30 + c2 * 0.15;
	c = smoothstep(0.50 - cloud_amount * 0.36, 0.88, c);
	return c * smoothstep(0.0, 0.24, dir.y);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = clamp(dir.y, -1.0, 1.0);

	// 하늘 그라디언트 — 지평선 쪽이 급격히 밝아진다
	float t = pow(clamp(up, 0.0, 1.0), 1.0 / horizon_sharp);
	vec3 col = mix(horizon_color, top_color, t);

	// 지면(수평선 아래)
	col = mix(col, ground_color, smoothstep(0.0, -0.06, up));

	// 별
	if (star_amount > 0.001 && up > -0.02) {
		col += vec3(0.85, 0.90, 1.0) * star_field(dir) * star_amount;
	}

	// 달
	vec3 md = normalize(moon_dir);
	float mdot = dot(dir, md);
	float moon_disk = smoothstep(0.9992, 0.9997, mdot);
	float moon_glow = pow(max(mdot, 0.0), 220.0);
	col += vec3(0.85, 0.90, 1.0) * (moon_disk * 1.6 + moon_glow * 0.35)
		* (1.0 - day_amount);

	// 태양 (LIGHT0 이 켜져 있을 때만)
	if (LIGHT0_ENABLED) {
		vec3 sd = -normalize(LIGHT0_DIRECTION);
		float sdot = dot(dir, sd);
		float disk = smoothstep(0.9990, 0.9996, sdot);
		float glow = pow(max(sdot, 0.0), 60.0);
		float wide = pow(max(sdot, 0.0), 6.0);
		col += sun_color * (disk * 6.0 + glow * 1.1 + wide * 0.22 * (1.0 + dusk_amount));
	}

	// 구름 — 낮에는 밝게, 노을엔 붉게, 밤엔 어둡게.
	// 두꺼운 부분은 밑면이 어두워야 뭉게구름처럼 보인다.
	float cl = clouds(dir);
	vec3 cloud_lit = mix(vec3(0.36, 0.38, 0.44), vec3(1.0, 0.99, 0.95), day_amount);
	vec3 cloud_dark = mix(vec3(0.16, 0.17, 0.22), vec3(0.52, 0.55, 0.62), day_amount);
	cloud_lit = mix(cloud_lit, vec3(1.0, 0.66, 0.40), dusk_amount * 0.85);
	cloud_dark = mix(cloud_dark, vec3(0.52, 0.26, 0.24), dusk_amount * 0.75);
	// 태양 쪽 구름은 가장자리가 환하게 탄다
	float sun_side = 0.0;
	if (LIGHT0_ENABLED) {
		sun_side = pow(max(dot(dir, -normalize(LIGHT0_DIRECTION)), 0.0), 3.0);
	}
	vec3 cloud_col = mix(cloud_dark, cloud_lit, clamp(cl * 0.75 + sun_side * 0.6, 0.0, 1.0));
	cloud_col += sun_color * sun_side * cl * 0.35;
	col = mix(col, cloud_col, cl * 0.90);

	// 지평선 헤이즈 — 먼 거리감을 만든다
	float haze = pow(1.0 - abs(up), 8.0);
	col = mix(col, horizon_color, haze * 0.35);

	COLOR = col;
}
"""

## 구름용 부드러운 노이즈 텍스처
static func make_cloud_texture(size: int = 128) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = 4242
	n.frequency = 3.5 / float(size)
	n.fractal_octaves = 5
	n.fractal_gain = 0.55
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			# 심리스 타일링
			var a := n.get_noise_2d(float(x), float(y))
			var b := n.get_noise_2d(float(x - size), float(y))
			var c := n.get_noise_2d(float(x), float(y - size))
			var d := n.get_noise_2d(float(x - size), float(y - size))
			var fx := float(x) / float(size)
			var fy := float(y) / float(size)
			var v: float = lerp(lerp(a, b, fx), lerp(c, d, fx), fy)
			v = clampf(v * 0.5 + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)
