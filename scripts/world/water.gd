class_name Water
extends Node3D
## 바다. 플레이어를 따라다니는 큰 파도 평면 + 수중 판정.

const TILE := 900.0
const SUBDIV := 90

var _mi: MeshInstance3D
var _step := 32.0

func _ready() -> void:
	name = "water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(TILE, TILE)
	pm.subdivide_width = SUBDIV
	pm.subdivide_depth = SUBDIV
	_mi = MeshInstance3D.new()
	_mi.mesh = pm
	_mi.material_override = MatLib.water_mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = TILE
	add_child(_mi)
	position.y = Const.WATER_LEVEL

func _process(_delta: float) -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	visible = not p.has_meta("in_dungeon")
	if not visible:
		return
	# 격자 단위로 스냅 이동 — 파도 위상이 흔들리지 않는다
	var pos := p.global_position
	global_position = Vector3(
		snappedf(pos.x, _step), Const.WATER_LEVEL, snappedf(pos.z, _step))

static func surface_y() -> float:
	return Const.WATER_LEVEL

static func is_under(pos: Vector3) -> bool:
	return pos.y < Const.WATER_LEVEL

## 발헤임식 수심 판정: 무릎 이상 잠기면 이동 감속, 가슴 이상이면 수영
static func depth_at(pos: Vector3) -> float:
	return Const.WATER_LEVEL - pos.y
