extends Node3D

const FONT: FontFile = preload("res://assets/fonts/NanumBarunGothicBold.ttf")
const SFX_MIX_RATE := 22050
const SFX_POOL_SIZE := 8
const REQUIRED_SFX := ["pickup", "hit", "heavy_hit", "hurt", "craft", "build", "warning", "boss"]
const SFX_DURATIONS := {
	"pickup": 0.14,
	"hit": 0.09,
	"heavy_hit": 0.17,
	"hurt": 0.20,
	"craft": 0.24,
	"build": 0.18,
	"warning": 0.30,
	"boss": 0.44,
}
const SFX_VOLUMES := {
	"pickup": -13.0,
	"hit": -15.0,
	"heavy_hit": -13.5,
	"hurt": -14.0,
	"craft": -14.0,
	"build": -14.0,
	"warning": -16.0,
	"boss": -17.0,
}
const SFX_SEEDS := {
	"pickup": 1193,
	"hit": 2081,
	"heavy_hit": 3253,
	"hurt": 4421,
	"craft": 5501,
	"build": 6673,
	"warning": 7817,
	"boss": 8999,
}

var game: Node
var rng := RandomNumberGenerator.new()
var sfx_bank: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var next_sfx_player := 0


func setup(owner_game: Node) -> void:
	game = owner_game
	rng.seed = 74193
	_build_sfx_bank()
	_create_sfx_pool()


func hit(world_position: Vector3, amount: int, color: Color = Color.WHITE, heavy: bool = false, play_audio: bool = true) -> void:
	if play_audio:
		play_sfx("heavy_hit" if heavy else "hit")
	var number := Label3D.new()
	number.text = str(amount)
	number.font = FONT
	number.font_size = 42 if heavy else 32
	number.modulate = color
	number.outline_size = 8
	number.outline_modulate = Color(0.04, 0.05, 0.045, 0.9)
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	number.position = world_position + Vector3(rng.randf_range(-0.2, 0.2), 1.4, 0.0)
	add_child(number)
	var number_tween := number.create_tween().set_parallel(true)
	number_tween.tween_property(number, "position", number.position + Vector3(0, 1.25, 0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	number_tween.tween_property(number, "modulate:a", 0.0, 0.8).set_delay(0.15)
	number_tween.chain().tween_callback(number.queue_free)

	var particle_color := color.lerp(Color(0.92, 0.78, 0.46), 0.35)
	for index in range(7 if heavy else 4):
		_spawn_chip(world_position + Vector3.UP, particle_color, index)

	if game != null and is_instance_valid(game) and game.player != null:
		game.player.add_camera_shake(0.18 if heavy else 0.08)


func burst(world_position: Vector3, color: Color, radius: float = 5.0) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = material
	ring.position = world_position + Vector3(0, 0.08, 0)
	ring.scale = Vector3(0.15, 0.06, 0.15)
	add_child(ring)
	var ring_tween := ring.create_tween().set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector3(radius, 0.04, radius), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(material, "albedo_color:a", 0.0, 0.65).set_delay(0.15)
	ring_tween.chain().tween_callback(ring.queue_free)


func player_hurt() -> void:
	play_sfx("hurt")
	if game != null and game.hud != null:
		game.hud.flash_damage()
	if game != null and game.player != null:
		game.player.add_camera_shake(0.3)


func play_sfx(sfx_id: String) -> void:
	if not sfx_bank.has(sfx_id) or sfx_players.is_empty():
		return
	var selected: AudioStreamPlayer
	for player in sfx_players:
		if not player.playing:
			selected = player
			break
	if selected == null:
		selected = sfx_players[next_sfx_player]
		selected.stop()
	next_sfx_player = (sfx_players.find(selected) + 1) % sfx_players.size()
	selected.stream = sfx_bank[sfx_id]
	selected.volume_db = float(SFX_VOLUMES.get(sfx_id, -15.0))
	selected.pitch_scale = 1.0
	selected.play()


func sfx_contract_valid() -> bool:
	if sfx_players.size() != SFX_POOL_SIZE:
		return false
	for sfx_id: String in REQUIRED_SFX:
		var stream: Variant = sfx_bank.get(sfx_id)
		if not stream is AudioStreamWAV:
			return false
		var wav := stream as AudioStreamWAV
		if wav.data.is_empty() or wav.mix_rate != SFX_MIX_RATE:
			return false
		if wav.get_length() <= 0.0 or wav.get_length() > 0.5:
			return false
	return true


func _build_sfx_bank() -> void:
	sfx_bank.clear()
	for sfx_id: String in REQUIRED_SFX:
		sfx_bank[sfx_id] = _synthesize_sfx(sfx_id)


func _create_sfx_pool() -> void:
	for player in sfx_players:
		if is_instance_valid(player):
			player.queue_free()
	sfx_players.clear()
	for index in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "ProceduralSFX%d" % index
		player.max_polyphony = 1
		add_child(player)
		sfx_players.append(player)


func _synthesize_sfx(sfx_id: String) -> AudioStreamWAV:
	var duration := float(SFX_DURATIONS[sfx_id])
	var sample_count := int(ceil(duration * float(SFX_MIX_RATE)))
	var pcm := PackedByteArray()
	var noise_state := int(SFX_SEEDS[sfx_id])
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(SFX_MIX_RATE)
		noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
		var noise := float(noise_state % 65536) / 32767.5 - 1.0
		var attack := minf(1.0, time / 0.006)
		var release := pow(maxf(0.0, 1.0 - time / duration), 1.7)
		var value := _sfx_wave(sfx_id, time, duration, noise) * attack * release
		var sample := clampi(int(round(value * 24500.0)), -32767, 32767)
		pcm.append(sample & 0xff)
		pcm.append((sample >> 8) & 0xff)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SFX_MIX_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


func _sfx_wave(sfx_id: String, time: float, duration: float, noise: float) -> float:
	var progress := time / duration
	match sfx_id:
		"pickup":
			var note := 620.0 if time < 0.065 else 880.0
			return sin(TAU * note * time) * 0.44 + sin(TAU * note * 2.0 * time) * 0.10
		"hit":
			return noise * 0.46 + sin(TAU * 145.0 * time) * 0.28
		"heavy_hit":
			return noise * 0.34 + sin(TAU * (92.0 - progress * 24.0) * time) * 0.48
		"hurt":
			var hurt_phase := 390.0 * time - 125.0 * time * time / duration
			return sin(TAU * hurt_phase) * 0.36 + noise * 0.22
		"craft":
			var note_index := mini(2, int(time / 0.075))
			var notes := [520.0, 660.0, 820.0]
			var pulse := 1.0 - fposmod(time, 0.075) / 0.075
			return sin(TAU * float(notes[note_index]) * time) * pulse * 0.48
		"build":
			var knock := maxf(0.0, 1.0 - time / 0.075)
			return noise * knock * 0.38 + sin(TAU * 118.0 * time) * 0.40
		"warning":
			var pulse := 0.58 + sin(TAU * 7.0 * time) * 0.24
			return sin(TAU * (178.0 - progress * 45.0) * time) * pulse
		"boss":
			var swell := sin(PI * clampf(progress, 0.0, 1.0))
			return (sin(TAU * 72.0 * time) * 0.42 + sin(TAU * 108.0 * time) * 0.20 + noise * 0.06) * swell
	return 0.0


func _spawn_chip(origin: Vector3, color: Color, index: int) -> void:
	var chip := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var size := rng.randf_range(0.05, 0.11)
	mesh.size = Vector3(size, size, size)
	chip.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	chip.material_override = material
	chip.position = origin
	chip.rotation = Vector3(rng.randf() * 3.0, rng.randf() * 3.0, rng.randf() * 3.0)
	add_child(chip)
	var direction := Vector3(cos(float(index) * 1.7), rng.randf_range(0.6, 1.2), sin(float(index) * 1.7)).normalized()
	var chip_tween := chip.create_tween()
	chip_tween.tween_property(chip, "position", origin + direction * rng.randf_range(0.5, 1.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	chip_tween.tween_property(chip, "position:y", origin.y - 0.15, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	chip_tween.parallel().tween_property(chip, "scale", Vector3.ZERO, 0.3)
	chip_tween.tween_callback(chip.queue_free)
