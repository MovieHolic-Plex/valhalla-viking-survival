class_name Runestone
extends StaticBody3D
## 전승이 새겨진 룬석. 상호작용하면 세계관 문구가 뜬다.
##
## 발헤임의 룬석과 같은 역할 — 전투 보상이 아니라 "여긴 어떤 곳인가"를
## 알려주는 장치다. 던전 서고 방과 지상 유적에 놓인다.

var lore_key := "LORE_1"
var _read := false
var _label: Label3D

static func make(key: String) -> Runestone:
	var r := Runestone.new()
	r.lore_key = key
	return r

func _ready() -> void:
	collision_layer = Const.L_BUILDING
	collision_mask = 0
	add_to_group("interactable")
	add_to_group("runestone")

	var mb := MeshBuilder.new()
	var stone := Color(0.40, 0.39, 0.37)
	# 위가 둥글게 다듬어진 비석
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.05, 0)), Vector3(1.5, 2.1, 0.34),
		stone)
	mb.cyl(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 2.1, 0)),
		0.75, 0.75, 0.34, 10, stone)
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), Vector3(2.0, 0.25, 0.9),
		stone.darkened(0.18))
	# 새겨진 룬 — 얕게 파인 홈처럼 어두운 띠 몇 줄
	var rng := RandomNumberGenerator.new()
	rng.seed = lore_key.hash()
	for i in range(5):
		var y := 0.55 + float(i) * 0.34
		var w := rng.randf_range(0.5, 1.05)
		mb.box(Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-0.2, 0.2), y, 0.18)),
			Vector3(w, 0.07, 0.03), Color(0.16, 0.18, 0.14))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.flat(Color.WHITE, 0.94)
	add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 2.4, 0.5)
	cs.shape = bs
	cs.position = Vector3(0, 1.2, 0)
	add_child(cs)

	# 룬이 은은하게 빛난다 — 어두운 던전에서 눈에 띄어야 한다
	var l := OmniLight3D.new()
	l.light_color = Color(0.55, 0.80, 0.95)
	l.light_energy = 0.9
	l.omni_range = 5.5
	l.shadow_enabled = false
	l.position = Vector3(0, 1.3, 0.4)
	add_child(l)
	Flicker.attach(l, 0.20, 0.5)

	_label = Label3D.new()
	_label.text = tr("UI_RUNESTONE")
	_label.font_size = 26
	_label.pixel_size = 0.004
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 7
	_label.modulate = Color(0.80, 0.88, 0.96)
	_label.position = Vector3(0, 2.9, 0)
	add_child(_label)

func can_interact(_p) -> bool:
	return true

func prompt() -> String:
	return tr("PROMPT_READ_RUNESTONE")

func interact(_player) -> void:
	GameState.msg(tr(lore_key))
	Sfx.play("ui_open", -8.0, 0.7)
	if not _read:
		_read = true
		GameState.stats["lore"] = int(GameState.stats.get("lore", 0)) + 1
