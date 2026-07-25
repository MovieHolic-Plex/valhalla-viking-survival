class_name PostFX
extends CanvasLayer
## 화면 후처리 오버레이 — 비네트 + 미세 색보정.
##
## 3D 위, HUD 아래에 깔린다(layer 가 음수면 CanvasLayer 0 보다 뒤).
## Environment 의 adjustment 로는 못 만드는 "가장자리만 어둡고 차갑게"를 담당한다.
## 발헤임 화면이 중앙으로 시선을 모으는 이유가 이 처리다.

const SHADER := """
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette_amount = 0.42;
uniform float vignette_softness = 0.55;
uniform float edge_desat = 0.35;
uniform vec3 shadow_tint : source_color = vec3(0.86, 0.92, 1.05);
uniform vec3 light_tint : source_color = vec3(1.04, 1.00, 0.94);
uniform float underwater = 0.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;

	// 밝은 곳은 따뜻하게, 어두운 곳은 차갑게 — 필름 컬러 그레이딩의 기본
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c *= mix(shadow_tint, light_tint, smoothstep(0.15, 0.75, l));

	// 비네트: 가장자리를 어둡히고 채도를 뺀다
	vec2 d = (SCREEN_UV - vec2(0.5)) * vec2(1.0, 0.72);
	float r = length(d) * 2.0;
	float v = smoothstep(1.0 - vignette_softness, 1.35, r);
	c *= 1.0 - v * vignette_amount;
	c = mix(c, vec3(l), v * edge_desat);

	// 수중에서는 화면 전체가 청록으로 잠긴다
	c = mix(c, c * vec3(0.42, 0.78, 0.86) + vec3(0.0, 0.03, 0.05), underwater);

	COLOR = vec4(c, 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _under := 0.0

func _ready() -> void:
	name = "postfx"
	layer = -5      # 3D 위, HUD(레이어 0 이상) 아래
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

func _process(delta: float) -> void:
	# 카메라가 수면 아래로 들어가면 부드럽게 청록 필터를 건다
	var want := 0.0
	var cam := get_viewport().get_camera_3d()
	var pl := GameState.player
	var in_dungeon: bool = pl != null and is_instance_valid(pl) \
		and pl.has_meta("in_dungeon")
	if cam != null and not in_dungeon and cam.global_position.y < Const.WATER_LEVEL:
		want = 1.0
	_under = move_toward(_under, want, delta * 4.0)
	_mat.set_shader_parameter("underwater", _under)
