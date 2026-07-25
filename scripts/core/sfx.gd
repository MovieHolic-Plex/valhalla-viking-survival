extends Node
## 절차적 사운드. 오토로드 이름: Sfx
## 외부 오디오 파일 없이 PCM 을 직접 합성한다.

const RATE := 22050
const POOL_2D := 12
const POOL_3D := 24

var _cache: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _i2 := 0
var _i3 := 0
var master_volume := 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_2D):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool2d.append(p)
	for i in range(POOL_3D):
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "Master"
		p3.unit_size = 12.0
		p3.max_distance = 60.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		add_child(p3)
		_pool3d.append(p3)

# ────────────────────────────────────────────────── 재생
func play(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream_for(id)
	if s == null:
		return
	var p := _pool2d[_i2]
	_i2 = (_i2 + 1) % POOL_2D
	p.stream = s
	p.volume_db = volume_db + linear_to_db(master_volume)
	p.pitch_scale = clampf(pitch * randf_range(0.95, 1.05), 0.2, 3.0)
	p.play()

func play_at(id: String, pos: Vector3, parent: Node, volume_db: float = 0.0,
		pitch: float = 1.0) -> void:
	var s := stream_for(id)
	if s == null or parent == null or not parent.is_inside_tree():
		return
	var p := _pool3d[_i3]
	_i3 = (_i3 + 1) % POOL_3D
	if p.get_parent() != self:
		p.reparent(self)
	p.stream = s
	p.volume_db = volume_db + linear_to_db(master_volume)
	p.pitch_scale = clampf(pitch * randf_range(0.92, 1.08), 0.2, 3.0)
	p.global_position = pos
	p.play()

func stream_for(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var s := _synth(id)
	_cache[id] = s
	return s

# ────────────────────────────────────────────────── 합성
func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

func _buf(dur: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(RATE * dur))
	a.fill(0.0)
	return a

static func _env(t: float, dur: float, attack: float, decay_pow: float) -> float:
	if t < attack:
		return t / maxf(attack, 0.0001)
	var x := (t - attack) / maxf(dur - attack, 0.0001)
	return pow(maxf(1.0 - x, 0.0), decay_pow)

func _synth(id: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()
	match id:
		"chop":                     # 도끼로 나무 찍기 — 저역 노이즈 + 나무 톤
			return _wav(_noise_tone(0.28, 180.0, 0.55, 0.006, 5.0, rng, 0.4))
		"tree_fall":
			return _wav(_noise_tone(1.6, 90.0, 0.75, 0.25, 1.6, rng, 0.55))
		"stone_hit":                # 곡괭이 — 고역 딱 소리
			return _wav(_noise_tone(0.22, 900.0, 0.75, 0.003, 8.0, rng, 0.25))
		"metal_hit":
			return _wav(_metal(0.45, [1400.0, 2100.0, 3300.0], rng))
		"flesh_hit":
			return _wav(_noise_tone(0.20, 240.0, 0.62, 0.004, 7.0, rng, 0.5))
		"swing":
			return _wav(_whoosh(0.26, rng))
		"bow_shoot":
			return _wav(_whoosh(0.18, rng, 2.0))
		"arrow_hit":
			return _wav(_noise_tone(0.14, 700.0, 0.6, 0.002, 12.0, rng, 0.3))
		"pickup":
			return _wav(_tones(0.16, [880.0, 1320.0], [0.0, 0.06], 0.28))
		"craft":
			return _wav(_tones(0.55, [523.0, 659.0, 784.0, 1046.0], [0.0, 0.09, 0.18, 0.27], 0.24))
		"click":
			return _wav(_tones(0.06, [1200.0], [0.0], 0.18))
		"error":
			return _wav(_tones(0.20, [220.0, 165.0], [0.0, 0.08], 0.22))
		"level_up":
			return _wav(_tones(0.9, [392.0, 523.0, 659.0, 784.0, 1046.0],
				[0.0, 0.1, 0.2, 0.3, 0.42], 0.26))
		"build":
			return _wav(_noise_tone(0.30, 320.0, 0.5, 0.005, 6.0, rng, 0.45))
		"footstep":
			return _wav(_noise_tone(0.13, 260.0, 0.85, 0.004, 10.0, rng, 0.18))
		"jump":
			return _wav(_whoosh(0.16, rng, 1.4))
		"land":
			return _wav(_noise_tone(0.22, 130.0, 0.8, 0.004, 7.0, rng, 0.30))
		"hurt":
			return _wav(_tones(0.30, [330.0, 247.0], [0.0, 0.08], 0.35, true))
		"death":
			return _wav(_tones(1.4, [220.0, 175.0, 147.0, 110.0], [0.0, 0.25, 0.5, 0.8], 0.4, true))
		"eat":
			return _wav(_noise_tone(0.32, 200.0, 0.7, 0.02, 3.0, rng, 0.22))
		"splash":
			return _wav(_noise_tone(0.55, 1200.0, 0.9, 0.01, 3.0, rng, 0.35))
		"portal":
			return _wav(_sweep(1.2, 200.0, 1600.0, 0.28))
		"boss_roar":
			return _wav(_roar(2.2, rng))
		"growl":
			return _wav(_roar(0.8, rng, 0.55))
		"fire":
			return _wav(_noise_tone(1.0, 400.0, 0.95, 0.2, 1.2, rng, 0.10), true)
		"wind":
			return _wav(_wind(4.0, rng), true)
		"thunder":
			return _wav(_noise_tone(1.8, 120.0, 0.9, 0.05, 2.0, rng, 0.6))
		"smelt":
			return _wav(_noise_tone(1.2, 300.0, 0.9, 0.3, 1.0, rng, 0.12), true)
		_:
			return _wav(_tones(0.1, [440.0], [0.0], 0.2))

## 노이즈 + 사인 혼합 타격음
func _noise_tone(dur: float, freq: float, noise_amt: float, attack: float,
		decay: float, rng: RandomNumberGenerator, amp: float) -> PackedFloat32Array:
	var a := _buf(dur)
	var lp := 0.0
	var alpha: float = clampf(freq / float(RATE) * 6.0, 0.02, 0.9)
	for i in a.size():
		var t := float(i) / float(RATE)
		var e := _env(t, dur, attack, decay)
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * alpha
		var s := sin(TAU * freq * t) * (1.0 - noise_amt) + lp * noise_amt
		a[i] = s * e * amp
	return a

## 금속 링잉 — 여러 배음의 감쇠 사인
func _metal(dur: float, freqs: Array, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var a := _buf(dur)
	for i in a.size():
		var t := float(i) / float(RATE)
		var s := 0.0
		for k in freqs.size():
			var f: float = freqs[k]
			s += sin(TAU * f * t) * pow(maxf(1.0 - t / dur, 0.0), 2.5 + float(k))
		s += rng.randf_range(-1.0, 1.0) * _env(t, dur, 0.001, 30.0) * 0.4
		a[i] = s / float(freqs.size() + 1) * 0.45
	return a

## 휙 소리 (밴드패스된 노이즈가 지나가는 느낌)
func _whoosh(dur: float, rng: RandomNumberGenerator, pitch: float = 1.0) -> PackedFloat32Array:
	var a := _buf(dur)
	var lp := 0.0
	var hp := 0.0
	for i in a.size():
		var t := float(i) / float(RATE)
		var x := t / dur
		var cutoff: float = (0.05 + sin(x * PI) * 0.35) * pitch
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * clampf(cutoff, 0.01, 0.95)
		hp = lp - hp * 0.02
		a[i] = lp * sin(x * PI) * 0.42
	return a

## 화음/멜로디
func _tones(dur: float, freqs: Array, starts: Array, amp: float,
		descend: bool = false) -> PackedFloat32Array:
	var a := _buf(dur)
	for k in freqs.size():
		var f: float = freqs[k]
		var s0: float = starts[k]
		for i in a.size():
			var t := float(i) / float(RATE)
			if t < s0:
				continue
			var lt := t - s0
			var seg: float = dur - s0
			var e := _env(lt, seg, 0.004, 3.5)
			var ff: float = f * (1.0 - lt * 0.15 if descend else 1.0)
			a[i] += (sin(TAU * ff * lt) * 0.7 + sin(TAU * ff * 2.0 * lt) * 0.3) * e * amp
	return a

func _sweep(dur: float, f0: float, f1: float, amp: float) -> PackedFloat32Array:
	var a := _buf(dur)
	var phase := 0.0
	for i in a.size():
		var t := float(i) / float(RATE)
		var x := t / dur
		var f: float = lerp(f0, f1, x * x)
		phase += TAU * f / float(RATE)
		a[i] = (sin(phase) * 0.6 + sin(phase * 1.5) * 0.4) * sin(x * PI) * amp
	return a

## 보스 포효 — 저역 톱니 + 노이즈 + 비브라토
func _roar(dur: float, rng: RandomNumberGenerator, amp: float = 0.75) -> PackedFloat32Array:
	var a := _buf(dur)
	var lp := 0.0
	var phase := 0.0
	for i in a.size():
		var t := float(i) / float(RATE)
		var x := t / dur
		var f: float = 70.0 + sin(t * 7.0) * 12.0 + (1.0 - x) * 45.0
		phase += TAU * f / float(RATE)
		var saw := fmod(phase, TAU) / PI - 1.0
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.06
		var e := _env(t, dur, 0.08, 1.6)
		a[i] = (saw * 0.6 + lp * 0.5) * e * amp
	return a

## 바람 — 느리게 변조되는 저역 노이즈(루프용)
func _wind(dur: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var a := _buf(dur)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / float(RATE)
		var mod: float = 0.5 + 0.5 * sin(t * 0.9) * sin(t * 0.37 + 1.0)
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.02
		a[i] = lp * (0.25 + mod * 0.55)
	# 루프 이음매를 부드럽게
	var fade := int(RATE * 0.25)
	for i in range(fade):
		var g := float(i) / float(fade)
		a[i] *= g
		a[a.size() - 1 - i] *= g
	return a
