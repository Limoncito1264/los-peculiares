extends Node
## Sistema centralizado de sonido para ODYSSEY-60.
## - Usa res://themes/Sonidotecla.wav para todos los botones de interfaz.
## - Genera efectos PCM limpios en memoria para telemetría, fallas, lanzamiento, órbita y explosión.
## - Si agregas archivos .wav/.ogg en res://audio/<nombre>.wav (o .ogg), los prioriza automáticamente.

const SAMPLE_RATE := 22050
const UI_CLICK_PATH := "res://themes/Sonidotecla.wav"

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer
var _muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	_build_library()
	_setup_ambient()
	_connect_game_events()

	get_tree().node_added.connect(_on_node_added)
	_hook_existing_buttons(get_tree().root)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			toggle_mute()


func toggle_mute() -> void:
	_muted = not _muted
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, _muted)


func is_muted() -> bool:
	return _muted


func play(sfx_name: String, volume_db: float = 0.0, pitch_jitter: float = 0.0) -> void:
	if _muted or not _streams.has(sfx_name):
		return
	var player := _get_free_player()
	player.stream = _streams[sfx_name]
	player.volume_db = volume_db
	if pitch_jitter > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	else:
		player.pitch_scale = 1.0
	player.play()


func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_bind_button(node as BaseButton)


func _hook_existing_buttons(root: Node) -> void:
	if root is BaseButton:
		_bind_button(root as BaseButton)
	for child in root.get_children():
		_hook_existing_buttons(child)


func _bind_button(btn: BaseButton) -> void:
	if btn.has_meta("_sfx_bound"):
		return
	btn.set_meta("_sfx_bound", true)
	btn.pressed.connect(func() -> void:
		play("click", -4.0, 0.04)
	)


func _connect_game_events() -> void:
	if not Events:
		return
	Events.sol_advanced.connect(func(_new_sol: int) -> void:
		play("sol", -5.0)
	)
	Events.part_state_changed.connect(func(idx: int) -> void:
		if GameManager and idx >= 0 and idx < GameManager.part_state.size():
			if GameManager.part_state[idx] == GameManager.PartState.READY:
				play("build_ready", -2.0)
			else:
				play("confirm", -5.0)
	)
	Events.adverse_event_triggered.connect(func(_id: String) -> void:
		play("alert", -2.0)
	)
	Events.signal_status_changed.connect(func(online: bool) -> void:
		if not online:
			play("alert", -3.0)
		else:
			play("confirm", -5.0)
	)
	Events.calendar_event_added.connect(func(_sol: int, _txt: String) -> void:
		play("confirm", -6.0)
	)


func _load_override(sfx_name: String) -> AudioStream:
	for ext in ["wav", "ogg", "mp3"]:
		var path := "res://audio/%s.%s" % [sfx_name, ext]
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				return res
	return null


func _build_library() -> void:
	# 1. Clic de teclado/interfaz (prioriza audio/click.* o res://themes/Sonidotecla.wav)
	var ov_click := _load_override("click")
	if ov_click:
		_streams["click"] = ov_click
	elif ResourceLoader.exists(UI_CLICK_PATH):
		_streams["click"] = load(UI_CLICK_PATH)
	else:
		_streams["click"] = _synth_tones([880.0], 0.045, 0.35, false)

	# 2. Efectos procedurales con soporte de reemplazo en res://audio/<nombre>.wav|ogg
	_streams["confirm"] = _or_override("confirm", _synth_tones([523.25, 659.25], 0.14, 0.35, false))
	_streams["sol"] = _or_override("sol", _synth_tones([392.0, 523.25], 0.16, 0.28, false))
	_streams["build_ready"] = _or_override("build_ready", _synth_tones([440.0, 554.37, 659.25, 880.0], 0.38, 0.40, false))
	_streams["alert"] = _or_override("alert", _synth_tones([240.0, 180.0, 240.0], 0.42, 0.45, true))
	_streams["launch"] = _or_override("launch", _synth_launch())
	_streams["orbit"] = _or_override("orbit", _synth_tones([330.0, 495.0, 660.0], 0.46, 0.35, false))
	_streams["explosion"] = _or_override("explosion", _synth_explosion())
	_streams["victory"] = _or_override("victory", _synth_tones([392.0, 493.88, 587.33, 783.99], 0.75, 0.42, false))
	_streams["gameover"] = _or_override("gameover", _synth_tones([293.66, 246.94, 196.0, 146.83], 0.85, 0.40, true))


func _or_override(sfx_name: String, fallback: AudioStream) -> AudioStream:
	var ov := _load_override(sfx_name)
	return ov if ov != null else fallback


func _setup_ambient() -> void:
	var ov_music := _load_override("music")
	if ov_music == null:
		ov_music = _load_override("ambient")
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -18.0
	if ov_music:
		_bgm_player.stream = ov_music
	else:
		_bgm_player.stream = _synth_space_hum(6.0)
	add_child(_bgm_player)
	_bgm_player.play()


func _make_pcm(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	wav.loop_begin = 0
	wav.loop_end = samples.size()
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = bytes
	return wav


func _synth_tones(freqs: Array, duration: float, gain: float, harsh: bool) -> AudioStreamWAV:
	var total := int(SAMPLE_RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var seg_len := maxi(1, total / maxi(1, freqs.size()))
	var phase := 0.0
	for i in total:
		var idx := mini(freqs.size() - 1, i / seg_len)
		var f: float = float(freqs[idx])
		phase += TAU * f / float(SAMPLE_RATE)
		var local_t := float(i % seg_len) / float(seg_len)
		var env := sin(minf(1.0, local_t * 8.0) * PI * 0.5) * pow(1.0 - local_t, 0.65)
		var wave := sin(phase)
		if harsh:
			wave = clampf(wave * 1.8, -1.0, 1.0) * 0.7 + sin(phase * 0.5) * 0.3
		buf[i] = wave * env * gain
	return _make_pcm(buf, false)


func _synth_launch() -> AudioStreamWAV:
	var duration := 1.15
	var total := int(SAMPLE_RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var lp := 0.0
	var phase := 0.0
	for i in total:
		var t := float(i) / float(total)
		var env := minf(1.0, t * 12.0) * pow(1.0 - t, 0.75)
		var white := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, white, 0.14)
		var freq := lerpf(62.0, 135.0, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var rumble := sin(phase) * 0.45 + lp * 0.75
		buf[i] = clampf(rumble * env * 0.65, -1.0, 1.0)
	return _make_pcm(buf, false)


func _synth_explosion() -> AudioStreamWAV:
	var duration := 1.1
	var total := int(SAMPLE_RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var lp := 0.0
	var phase := 0.0
	for i in total:
		var t := float(i) / float(total)
		var env := minf(1.0, t * 45.0) * pow(1.0 - t, 1.6)
		var white := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, white, lerpf(0.32, 0.05, t))
		var sub_f := lerpf(110.0, 28.0, t)
		phase += TAU * sub_f / float(SAMPLE_RATE)
		var sig := lp * 0.85 + sin(phase) * 0.65
		buf[i] = clampf(sig * env * 0.85, -1.0, 1.0)
	return _make_pcm(buf, false)


func _synth_space_hum(duration: float) -> AudioStreamWAV:
	var total := int(SAMPLE_RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for i in total:
		var t := float(i) / float(SAMPLE_RATE)
		var lfo := 0.75 + 0.25 * sin(TAU * t / duration)
		var s := sin(TAU * 55.0 * t) * 0.45 + sin(TAU * 82.41 * t) * 0.30 + sin(TAU * 110.0 * t) * 0.15
		buf[i] = s * lfo * 0.16
	return _make_pcm(buf, true)
