class_name LaunchSlingshot
extends Control
## Lanzamiento orbital tipo resortera (balance intermedio):
## - Órbita dinámica de Marte (en la guía predictiva y en el vuelo real).
## - 3 desechos orbitales con movimiento lento.
## - Control de velocidad máxima de inserción en Marte con indicador visual en HUD.
## - Física 100% idéntica entre la guía de puntos y el vuelo real.

signal finished(success: bool)

enum State { AIMING, FLYING, RESULT }

# --- Mundo virtual (se escala a cualquier tamaño de ventana) ---
const W: float = 1280.0
const H: float = 720.0
const DT: float = 1.0 / 60.0

# --- Resortera ---
const K: float = 3.65              # velocidad de salida = estiramiento * K * power
const PMAX: float = 150.0          # estiramiento máximo (px)
const PMIN: float = 20.0           # estiramiento mínimo para disparar
const GRAB_R: float = 70.0         # radio para agarrar el cohete
const BASE := Vector2(200, 560)    # plataforma de la torre
const ANCHOR := Vector2(200, 546)  # posición de reposo del cohete
const POST_L := Vector2(178, 534)
const POST_R := Vector2(222, 534)

# --- Cuerpos celestes y física orbital ---
const EARTH_C := Vector2(200, 1050)
const EARTH_R: float = 380.0
const MU_E: float = 2.75e7
const MARS_BASE := Vector2(1095, 315)
const MARS_R: float = 48.0
const MARS_ORBIT_R: float = 88.0
const MU_M: float = 1.8e6
const SOFT: float = 400.0
const MAX_FLIGHT_TIME: float = 12.5
const MAX_CAPTURE_SPEED: float = 415.0

## true = práctica (se puede reintentar). false = intento único (lanzamiento final).
var practice: bool = true
## Multiplicador de potencia (p. ej. según el motor fabricado).
var power: float = 1.0
## Segundos de trayectoria guiada que se muestran al apuntar.
var preview_seconds: float = 1.45

var _state: State = State.AIMING
var _pulling: bool = false
var _pull_pos: Vector2 = ANCHOR
var _pos: Vector2 = ANCHOR
var _vel: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _sim_clock: float = 0.0
var _mars_phase0: float = 0.25
var _steps: int = 0
var _attempts: int = 1
var _explode_at: float = -1.0
var _explode_reason: String = ""
var _success: bool = false
var _last_why: String = ""
var _fade_out_alpha: float = 0.0
var _cinematic_started: bool = false
var _result_title: String = ""
var _result_sub: String = ""
var _trail: PackedVector2Array = PackedVector2Array()
var _stars: PackedVector2Array = PackedVector2Array()

var _pp: PackedVector2Array = PackedVector2Array()   # partículas: posición
var _pv: PackedVector2Array = PackedVector2Array()   # partículas: velocidad
var _pl: PackedFloat32Array = PackedFloat32Array()   # partículas: vida
var _p_color: Color = AresUI.AMBER

var _scale: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _btn_retry: Button
var _btn_close: Button


static func open(host: Node, is_practice: bool = true, power_mult: float = 1.0) -> LaunchSlingshot:
	var s := LaunchSlingshot.new()
	s.practice = is_practice
	s.power = power_mult
	host.add_child(s)
	return s


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 80:
		_stars.append(Vector2(rng.randf_range(0.0, W), rng.randf_range(0.0, H)))

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bar)

	if GameManager:
		preview_seconds = GameManager.get_launch_preview_seconds()

	_btn_retry = AresUI.button("REINTENTAR", "teal", 42)
	_btn_retry.custom_minimum_size = Vector2(170, 42)
	_btn_retry.pressed.connect(_reset)
	_btn_retry.visible = false
	bar.add_child(_btn_retry)

	_btn_close = AresUI.button("VOLVER A CABINA" if practice else "ABORTAR", "secondary", 42)
	_btn_close.custom_minimum_size = Vector2(180, 42)
	_btn_close.pressed.connect(_on_close)
	bar.add_child(_btn_close)


func _on_close() -> void:
	finished.emit(_success)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()


# ------------------------------------------------------------------
# Cinemática orbital (idéntica en predicción y en vuelo real)
# ------------------------------------------------------------------
func _mars_pos_at(flight_t: float) -> Vector2:
	var phase := _mars_phase0 + (_sim_clock + flight_t) * 0.42
	return MARS_BASE + Vector2(cos(phase) * 68.0, sin(phase) * 135.0)


func _obstacles_at(flight_t: float) -> Array[Vector3]:
	var t := _sim_clock + flight_t
	return [
		Vector3(580.0 + sin(t * 0.45) * 20.0, 310.0 + cos(t * 0.45) * 70.0, 25.0),
		Vector3(775.0 + cos(t * 0.40) * 18.0, 465.0 - sin(t * 0.40) * 75.0, 23.0),
		Vector3(875.0 + sin(t * 0.50 + 1.2) * 16.0, 225.0 + cos(t * 0.50 + 1.2) * 65.0, 21.0),
	]


func _pull_from(p: Vector2, c: Vector2, mu: float) -> Vector2:
	var d: Vector2 = c - p
	var d2: float = d.length_squared() + SOFT
	return d / sqrt(d2) * (mu / d2)


func _accel(p: Vector2, flight_t: float) -> Vector2:
	return _pull_from(p, EARTH_C, MU_E) + _pull_from(p, _mars_pos_at(flight_t), MU_M)


## Devuelve [nueva_posición, nueva_velocidad].
func _step(p: Vector2, v: Vector2, flight_t: float) -> PackedVector2Array:
	var nv: Vector2 = v + _accel(p, flight_t) * DT
	var np: Vector2 = p + nv * DT
	return PackedVector2Array([np, nv])


## "" = sigue volando; "mars", "mars_fast", "earth", "obstacle", "fuel", "out".
func _check(p: Vector2, v: Vector2, step: int, flight_t: float) -> String:
	var mc := _mars_pos_at(flight_t)
	if p.distance_to(mc) < MARS_R:
		if v.length() > MAX_CAPTURE_SPEED:
			return "mars_fast"
		return "mars"
	if step > 5 and p.distance_to(EARTH_C) < EARTH_R:
		return "earth"
	for o in _obstacles_at(flight_t):
		if p.distance_to(Vector2(o.x, o.y)) < o.z + 6.0:
			return "obstacle"
	if flight_t > MAX_FLIGHT_TIME:
		return "fuel"
	if p.x < -90.0 or p.x > W + 110.0 or p.y < -140.0 or p.y > H + 160.0:
		return "out"
	return ""


func _launch_vel() -> Vector2:
	return (ANCHOR - _pull_pos) * K * power


func _physics_process(_delta: float) -> void:
	if _state == State.AIMING:
		_sim_clock += DT
		return
	if _state != State.FLYING:
		return
	var res: PackedVector2Array = _step(_pos, _vel, _t)
	_pos = res[0]
	_vel = res[1]
	_t += DT
	_steps += 1
	if _steps % 2 == 0:
		_trail.append(_pos)
	var why: String = _check(_pos, _vel, _steps, _t)
	if why == "" and _explode_at > 0.0 and _t >= _explode_at:
		why = "explosion"
	if why != "":
		_end_flight(why)


func _process(delta: float) -> void:
	var i: int = _pl.size() - 1
	while i >= 0:
		_pl[i] -= delta
		if _pl[i] <= 0.0:
			_pp.remove_at(i)
			_pv.remove_at(i)
			_pl.remove_at(i)
		else:
			_pp[i] += _pv[i] * delta
		i -= 1
	if not practice and _last_why != "" and not _cinematic_started:
		_fade_out_alpha = minf(1.0, _fade_out_alpha + delta * 1.65)
		if _fade_out_alpha >= 1.0:
			_cinematic_started = true
			_launch_ending_cutscene()
	queue_redraw()


func _end_flight(why: String) -> void:
	_state = State.RESULT
	_success = why == "mars"
	var listos := GameManager.systems_ready() if GameManager else 4
	var total := GameManager.ROCKET_PARTS.size() if GameManager else 4
	var mc := _mars_pos_at(_t)
	match why:
		"mars":
			if practice and listos < total:
				_result_title = "TRAYECTORIA VÁLIDA · NAVE INCOMPLETA"
				_result_sub = "Órbita lograda en %.1f s (%.0f u/s), pero faltan %d/%d sistemas." % [_t, _vel.length(), total - listos, total]
				_burst(mc, AresUI.AMBER, 38)
			else:
				_result_title = "¡LLEGASTE A MARTE!"
				_result_sub = "Inserción orbital lograda en %.1f s a %.0f u/s." % [_t, _vel.length()]
				_burst(mc, AresUI.TEAL, 44)
		"mars_fast":
			_result_title = "EXCESO DE VELOCIDAD EN INSERCIÓN"
			_result_sub = "Entraste a %.0f u/s (máx. %.0f u/s). Baja potencia o usa arco alto." % [_vel.length(), MAX_CAPTURE_SPEED]
			_burst(_pos, Color("#E05A47"), 40)
		"earth":
			_result_title = "LA NAVE CAYÓ A LA TIERRA"
			_result_sub = "No alcanzó la velocidad de escape. Estira más la resortera."
			_burst(_pos, AresUI.AMBER, 36)
		"obstacle":
			_result_title = "IMPACTO CON DESECHOS ORBITALES"
			_result_sub = "Corrige el ángulo o aprovecha el movimiento para esquivarlos."
			_burst(_pos, Color("#E05A47"), 38)
		"explosion":
			_result_title = "¡EXPLOSIÓN DE LA NAVE!"
			_result_sub = "%s (T+%.1f s)." % [_explode_reason, _t]
			_burst(_pos, Color("#E05A47"), 56)
		"fuel":
			_result_title = "COMBUSTIBLE AGOTADO EN TRÁNSITO"
			_result_sub = "Superaste los %.1f s de vuelo sin alcanzar Marte." % MAX_FLIGHT_TIME
			_burst(_pos, AresUI.AMBER, 32)
		_:
			_result_title = "NAVE PERDIDA EN EL ESPACIO"
			_result_sub = "Te pasaste de Marte. Ajusta potencia y ángulo."
	_last_why = why
	_btn_retry.visible = practice
	if not practice:
		_btn_close.visible = false


func _burst(at: Vector2, color: Color, count: int) -> void:
	_p_color = color
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var c: Vector2 = Vector2(clampf(at.x, 20.0, W - 20.0), clampf(at.y, 20.0, H - 20.0))
	for i in count:
		var a: float = rng.randf_range(0.0, TAU)
		var s: float = rng.randf_range(40.0, 220.0)
		_pp.append(c)
		_pv.append(Vector2(cos(a), sin(a)) * s)
		_pl.append(rng.randf_range(0.5, 1.3))


func _reset() -> void:
	_state = State.AIMING
	_pulling = false
	_pull_pos = ANCHOR
	_pos = ANCHOR
	_vel = Vector2.ZERO
	_t = 0.0
	_steps = 0
	_success = false
	_trail = PackedVector2Array()
	_attempts += 1
	_mars_phase0 = fmod(_mars_phase0 + 0.45, TAU)
	_btn_retry.visible = false


# ------------------------------------------------------------------
# Entrada
# ------------------------------------------------------------------
func _update_layout() -> void:
	_scale = minf(size.x / W, size.y / H)
	_offset = (size - Vector2(W, H) * _scale) * 0.5


func _to_world(p: Vector2) -> Vector2:
	return (p - _offset) / _scale


func _update_pull(world: Vector2) -> void:
	var v: Vector2 = world - ANCHOR
	if v.length() > PMAX:
		v = v.normalized() * PMAX
	var pos: Vector2 = ANCHOR + v
	var from_earth: Vector2 = pos - EARTH_C
	if from_earth.length() < EARTH_R + 8.0:
		pos = EARTH_C + from_earth.normalized() * (EARTH_R + 8.0)
	_pull_pos = pos


func _gui_input(event: InputEvent) -> void:
	_update_layout()
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var w: Vector2 = _to_world(mb.position)
		if mb.pressed:
			if _state == State.AIMING and w.distance_to(ANCHOR) <= GRAB_R:
				_pulling = true
				_update_pull(w)
				accept_event()
		elif _pulling:
			_pulling = false
			if (ANCHOR - _pull_pos).length() >= PMIN:
				_fire()
			else:
				_pull_pos = ANCHOR
			accept_event()
	elif event is InputEventMouseMotion and _pulling:
		var mm: InputEventMouseMotion = event
		_update_pull(_to_world(mm.position))
		accept_event()


func _fire() -> void:
	_vel = _launch_vel()
	_pos = ANCHOR
	_t = 0.0
	_steps = 0
	_trail = PackedVector2Array([ANCHOR])
	_state = State.FLYING
	if not practice and _btn_close:
		_btn_close.visible = false
	_roll_explosion_risk()


func _roll_explosion_risk() -> void:
	_explode_at = -1.0
	_explode_reason = ""
	var listos := GameManager.systems_ready() if GameManager else 4
	var total := GameManager.ROCKET_PARTS.size() if GameManager else 4
	var risk: float = 0.04
	if listos < total:
		risk = 0.45
	elif GameManager:
		if GameManager.orbital_alignment < 75.0:
			risk += 0.12
		if GameManager.total_mass > GameManager.launch_capacity * 0.92:
			risk += 0.10
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() < risk:
		var en_despegue := rng.randf() < 0.45
		_explode_at = rng.randf_range(0.55, 1.35) if en_despegue else rng.randf_range(2.4, 5.2)
		if listos < total:
			_explode_reason = "FALLO POR SISTEMAS SIN FABRICAR (%d/%d)" % [listos, total]
		elif en_despegue:
			_explode_reason = "SOBREPRESIÓN EN IGNICIÓN DURANTE EL DESPEGUE"
		else:
			_explode_reason = "RUPTURA DEL PROPULSOR EN PLENO TRÁNSITO"


# ------------------------------------------------------------------
# Dibujo
# ------------------------------------------------------------------
func _draw() -> void:
	_update_layout()
	var font: Font = ThemeDB.fallback_font

	# Fondo (coordenadas de pantalla)
	draw_rect(Rect2(Vector2.ZERO, size), AresUI.BG_DEEP)
	draw_set_transform(_offset, 0.0, Vector2(_scale, _scale))

	# Cuadrícula y estrellas
	var gx: float = 0.0
	while gx <= W:
		draw_line(Vector2(gx, 0), Vector2(gx, H), Color(AresUI.GRID, 0.45), 1.0)
		gx += 80.0
	var gy: float = 0.0
	while gy <= H:
		draw_line(Vector2(0, gy), Vector2(W, gy), Color(AresUI.GRID, 0.45), 1.0)
		gy += 80.0
	for s in _stars:
		draw_circle(s, 1.4, Color(AresUI.TEXT, 0.35))

	# Tierra
	draw_circle(EARTH_C, EARTH_R, Color("12302f"))
	draw_arc(EARTH_C, EARTH_R + 14.0, 0.0, TAU, 160, Color(AresUI.TEAL, 0.22), 2.0)
	draw_arc(EARTH_C, EARTH_R, 0.0, TAU, 160, AresUI.TEAL, 3.0)
	draw_string(font, Vector2(336, 682), "TIERRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AresUI.TEAL)

	# Arco orbital tenue de Marte
	var orbit_pts := PackedVector2Array()
	for k in 65:
		var ph := float(k) / 64.0 * TAU
		orbit_pts.append(MARS_BASE + Vector2(cos(ph) * 68.0, sin(ph) * 135.0))
	draw_polyline(orbit_pts, Color(AresUI.AMBER, 0.22), 1.5)

	# Marte en su posición orbital actual + anillo indicador de velocidad de inserción
	var cur_t := _t if _state != State.AIMING else 0.0
	var mc := _mars_pos_at(cur_t)
	var vel_segura := (_state != State.FLYING) or (_vel.length() <= MAX_CAPTURE_SPEED)
	var ring_col := Color(AresUI.TEAL, 0.36) if vel_segura else Color("#E05A47", 0.50)
	draw_arc(mc, MARS_ORBIT_R, 0.0, TAU, 64, ring_col, 2.0)
	draw_circle(mc, MARS_R, Color("a4482f"))
	draw_circle(mc + Vector2(-12, -9), 10.0, Color("8a3a26"))
	draw_circle(mc + Vector2(14, 12), 7.5, Color("8a3a26"))
	draw_arc(mc, MARS_R, 0.0, TAU, 64, AresUI.AMBER, 2.0)
	draw_string(font, mc + Vector2(-26, -MARS_R - 12.0), "MARTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AresUI.AMBER)

	# 3 desechos orbitales con movimiento lento
	for o in _obstacles_at(cur_t):
		var oc: Vector2 = Vector2(o.x, o.y)
		draw_circle(oc, o.z, Color("4a5560"))
		draw_circle(oc + Vector2(-5, -4), o.z * 0.35, Color("38424b"))
		draw_arc(oc, o.z, 0.0, TAU, 32, AresUI.MUTED, 2.0)

	_draw_tower()

	# Estela del vuelo
	if _trail.size() >= 2:
		draw_polyline(_trail, Color(AresUI.TEAL, 0.55), 2.0)

	# Trayectoria guiada + posición futura de Marte
	if _pulling and (ANCHOR - _pull_pos).length() >= PMIN:
		_draw_preview(font)

	# Banda trasera, cohete y banda delantera
	var rocket_pos: Vector2 = ANCHOR
	var rocket_angle: float = -PI / 2.0
	var show_rocket: bool = true
	match _state:
		State.AIMING:
			if _pulling:
				rocket_pos = _pull_pos
				rocket_angle = (ANCHOR - _pull_pos).angle()
		State.FLYING:
			rocket_pos = _pos
			rocket_angle = _vel.angle()
		State.RESULT:
			show_rocket = false
	var band_col: Color = AresUI.AMBER.darkened(0.15)
	if _state == State.AIMING:
		draw_line(POST_R, rocket_pos, band_col.darkened(0.3), 4.0)
		_draw_rocket(rocket_pos, rocket_angle, false)
		draw_line(POST_L, rocket_pos, band_col, 4.0)
	else:
		draw_line(POST_L, ANCHOR + Vector2(0, 10), band_col, 3.0)
		draw_line(POST_R, ANCHOR + Vector2(0, 10), band_col, 3.0)
		if show_rocket:
			_draw_rocket(rocket_pos, rocket_angle, _state == State.FLYING)

	# Partículas
	for i in _pp.size():
		var a: float = clampf(_pl[i], 0.0, 1.0)
		draw_circle(_pp[i], 3.0, Color(_p_color, a))

	_draw_hud(font)
	if _fade_out_alpha > 0.001:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, _fade_out_alpha))


func _launch_ending_cutscene() -> void:
	var end_kind := "missed"
	match _last_why:
		"mars":
			end_kind = "victory"
		"mars_fast":
			end_kind = "crash"
		"explosion", "earth", "obstacle":
			end_kind = "explosion"
		_:
			end_kind = "missed"
	var host := get_parent() if get_parent() else get_tree().current_scene
	EndingCutscene.play(host, end_kind, _explode_reason)
	finished.emit(_success)
	queue_free()


func _draw_tower() -> void:
	var tower: PackedVector2Array = PackedVector2Array([
		Vector2(172, 674), Vector2(228, 674), Vector2(214, 560), Vector2(186, 560)])
	draw_colored_polygon(tower, AresUI.BG_PANEL)
	draw_polyline(PackedVector2Array([tower[0], tower[3], tower[2], tower[1]]), AresUI.BORDER, 2.0)
	draw_line(Vector2(178, 640), Vector2(222, 640), AresUI.BORDER, 2.0)
	draw_line(Vector2(182, 600), Vector2(218, 600), AresUI.BORDER, 2.0)
	draw_rect(Rect2(Vector2(172, 556), Vector2(56, 8)), AresUI.LAUNCH_BORDER)
	draw_line(Vector2(186, 558), POST_L, AresUI.LAUNCH_BORDER, 6.0)
	draw_line(Vector2(214, 558), POST_R, AresUI.LAUNCH_BORDER, 6.0)
	draw_circle(POST_L, 5.0, AresUI.AMBER)
	draw_circle(POST_R, 5.0, AresUI.AMBER)


func _draw_rocket(at: Vector2, angle: float, flame: bool) -> void:
	var xf := Transform2D(angle, at)
	var body: PackedVector2Array = PackedVector2Array([
		xf * Vector2(22, 0), xf * Vector2(10, -7), xf * Vector2(-16, -7),
		xf * Vector2(-16, 7), xf * Vector2(10, 7)])
	var fin_a: PackedVector2Array = PackedVector2Array([
		xf * Vector2(-6, -7), xf * Vector2(-18, -15), xf * Vector2(-18, -7)])
	var fin_b: PackedVector2Array = PackedVector2Array([
		xf * Vector2(-6, 7), xf * Vector2(-18, 15), xf * Vector2(-18, 7)])
	if flame:
		var flame_len: float = 14.0 + randf() * 10.0
		var fl: PackedVector2Array = PackedVector2Array([
			xf * Vector2(-16, -4), xf * Vector2(-16, 4), xf * Vector2(-16.0 - flame_len, 0)])
		draw_colored_polygon(fl, AresUI.AMBER)
	draw_colored_polygon(fin_a, AresUI.AMBER)
	draw_colored_polygon(fin_b, AresUI.AMBER)
	draw_colored_polygon(body, AresUI.TEXT)
	draw_circle(xf * Vector2(4, 0), 3.0, AresUI.TEAL)


func _draw_preview(font: Font) -> void:
	var p: Vector2 = ANCHOR
	var v: Vector2 = _launch_vel()
	var n: int = int(preview_seconds / DT)
	var end_t: float = 0.0
	for i in n:
		var ft := float(i + 1) * DT
		end_t = ft
		var res: PackedVector2Array = _step(p, v, ft)
		p = res[0]
		v = res[1]
		var why: String = _check(p, v, i, ft)
		if why != "":
			var impact_col := AresUI.TEAL if why == "mars" else Color("#E05A47")
			draw_arc(p, 10.0, 0.0, TAU, 20, impact_col, 2.0)
			break
		if i % 4 == 0:
			var f: float = 1.0 - float(i) / float(n)
			draw_circle(p, 2.0 + 3.0 * f, Color(AresUI.TEAL, 0.25 + 0.65 * f))

	# Marcador fantasma de dónde estará Marte al final de la línea guía
	var future_mars := _mars_pos_at(end_t)
	draw_line(_mars_pos_at(0.0), future_mars, Color(AresUI.AMBER, 0.25), 1.5)
	draw_arc(future_mars, MARS_R, 0.0, TAU, 28, Color(AresUI.AMBER, 0.42), 1.5)
	draw_string(font, future_mars + Vector2(-24, MARS_R + 14.0), "T+%.1fs" % end_t,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(AresUI.AMBER, 0.65))


func _draw_hud(font: Font) -> void:
	var mode_title := "MODO SIMULACIÓN · SIN RIESGO" if practice else "LANZAMIENTO FINAL · OPERACIÓN IRREVERSIBLE"
	var mode_col := AresUI.TEAL if practice else AresUI.AMBER
	draw_string(font, Vector2(28, 38), mode_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, mode_col)
	var hint: String = "Anticipa la órbita de Marte, esquiva los desechos y entra bajo %.0f u/s." % MAX_CAPTURE_SPEED
	if _state == State.FLYING:
		hint = "En vuelo hacia órbita marciana..."
	elif _state == State.RESULT and practice:
		hint = "Resultado del intento."
	draw_string(font, Vector2(28, 62), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AresUI.MUTED)

	var listos := GameManager.systems_ready() if GameManager else 4
	var total := GameManager.ROCKET_PARTS.size() if GameManager else 4
	var sub_info := "INTENTO %d  ·  SISTEMAS %d/%d  ·  GUÍA %.2fs" % [_attempts, listos, total, preview_seconds]
	if not practice:
		sub_info = "INTENTO ÚNICO  ·  SISTEMAS %d/%d  ·  GUÍA %.2fs" % [listos, total, preview_seconds]
	draw_string(font, Vector2(28, 86), sub_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AresUI.MUTED)

	if GameManager:
		var sol_txt := "VENTANA DE DESPEGUE: SOL %d / %d" % [GameManager.current_sol, GameManager.MAX_SOLS]
		draw_string(font, Vector2(W - 340.0, 38), sol_txt, HORIZONTAL_ALIGNMENT_RIGHT, 312.0, 13, AresUI.AMBER)

	if _pulling:
		var lv: Vector2 = _launch_vel()
		var pct: int = int(round((ANCHOR - _pull_pos).length() / PMAX * 100.0))
		var deg: int = int(round(rad_to_deg(-lv.angle())))
		draw_string(font, Vector2(28, 118), "POTENCIA   %d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AresUI.TEAL)
		draw_string(font, Vector2(28, 140), "ÁNGULO     %d°" % deg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AresUI.TEAL)
		draw_string(font, Vector2(28, 162), "VEL. INIC. %.0f u/s" % lv.length(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AresUI.MUTED)
	elif _state == State.FLYING:
		var spd := _vel.length()
		var spd_ok := spd <= MAX_CAPTURE_SPEED
		var spd_col := AresUI.TEAL if spd_ok else Color("#E05A47")
		var spd_tag := "OK" if spd_ok else "EXCESO DE VELOCIDAD"
		draw_string(font, Vector2(28, 118), "TIEMPO VUELO %.1f / %.1f s" % [_t, MAX_FLIGHT_TIME], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AresUI.TEAL)
		draw_string(font, Vector2(28, 140), "VELOCIDAD    %.0f / %.0f u/s (%s)" % [spd, MAX_CAPTURE_SPEED, spd_tag], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, spd_col)
		draw_string(font, Vector2(28, 162), "DIST. MARTE  %d u" % int(_pos.distance_to(_mars_pos_at(_t))), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AresUI.MUTED)

	if _state == State.RESULT and practice:
		var box := Rect2(Vector2(W * 0.5 - 370.0, 240.0), Vector2(740.0, 148.0))
		var incompleto := practice and _success and listos < total
		var accent: Color = AresUI.TEAL if (_success and not incompleto) else AresUI.AMBER
		draw_rect(box, Color(AresUI.BG_PANEL, 0.95))
		draw_rect(box, accent, false, 2.0)
		draw_string(font, box.position + Vector2(0, 52), _result_title,
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 25, accent)
		draw_string(font, box.position + Vector2(0, 90), _result_sub,
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 14, AresUI.TEXT)
		var foot_msg := "Pulsa REINTENTAR para probar otra trayectoria o VOLVER A CABINA." if practice else ("Pulsa CONTINUAR para completar la misión." if _success else "Pulsa VOLVER A CABINA para revisar la misión.")
		draw_string(font, box.position + Vector2(0, 122), foot_msg,
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 12, AresUI.MUTED)
