class_name LaunchSlingshot
extends Control
## Lanzamiento tipo "resortera": la base del cohete es el tirachinas.
## Arrastra el cohete hacia atrás, mira la trayectoria guiada (puntos) y suelta.
## La gravedad de la Tierra y de Marte curva la trayectoria; los desechos destruyen la nave.
##
## Uso:
##   var s := LaunchSlingshot.open(get_tree().current_scene, false)
##   s.finished.connect(func(ok: bool): print("Éxito: ", ok))

signal finished(success: bool)

enum State { AIMING, FLYING, RESULT }

# --- Mundo virtual (se escala a cualquier tamaño de ventana) ---
const W: float = 1280.0
const H: float = 720.0
const DT: float = 1.0 / 60.0

# --- Resortera ---
const K: float = 3.6               # velocidad de salida = estiramiento * K * power
const PMAX: float = 150.0          # estiramiento máximo (px)
const PMIN: float = 18.0           # estiramiento mínimo para disparar
const GRAB_R: float = 70.0         # radio para agarrar el cohete
const BASE := Vector2(200, 560)    # plataforma de la torre
const ANCHOR := Vector2(200, 546)  # posición de reposo del cohete
const POST_L := Vector2(178, 534)
const POST_R := Vector2(222, 534)

# --- Cuerpos celestes ---
const EARTH_C := Vector2(200, 1050)
const EARTH_R: float = 380.0
const MU_E: float = 2.6e7
const MARS_C := Vector2(1100, 300)
const MARS_R: float = 52.0
const MU_M: float = 1.6e6
const SOFT: float = 400.0

## true = práctica (se puede reintentar). false = intento único (lanzamiento final).
var practice: bool = true
## Multiplicador de potencia (p. ej. según el motor fabricado).
var power: float = 1.0
## Segundos de trayectoria guiada que se muestran al apuntar.
var preview_seconds: float = 1.6

var _state: State = State.AIMING
var _pulling: bool = false
var _pull_pos: Vector2 = ANCHOR
var _pos: Vector2 = ANCHOR
var _vel: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _steps: int = 0
var _attempts: int = 1
var _success: bool = false
var _result_title: String = ""
var _result_sub: String = ""
var _trail: PackedVector2Array = PackedVector2Array()
var _obstacles: Array[Vector3] = [Vector3(640, 330, 26), Vector3(860, 520, 22)]
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

	_btn_retry = AresUI.button("REINTENTAR", "teal", 42)
	_btn_retry.custom_minimum_size = Vector2(170, 42)
	_btn_retry.pressed.connect(_reset)
	_btn_retry.visible = false
	bar.add_child(_btn_retry)

	_btn_close = AresUI.button("CERRAR" if practice else "SALIR", "secondary", 42)
	_btn_close.custom_minimum_size = Vector2(150, 42)
	_btn_close.pressed.connect(_on_close)
	bar.add_child(_btn_close)


func _on_close() -> void:
	finished.emit(_success)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()


# ------------------------------------------------------------------
# Física (la misma para la guía y para el vuelo real)
# ------------------------------------------------------------------
func _pull_from(p: Vector2, c: Vector2, mu: float) -> Vector2:
	var d: Vector2 = c - p
	var d2: float = d.length_squared() + SOFT
	return d / sqrt(d2) * (mu / d2)


func _accel(p: Vector2) -> Vector2:
	return _pull_from(p, EARTH_C, MU_E) + _pull_from(p, MARS_C, MU_M)


## Devuelve [nueva_posición, nueva_velocidad].
func _step(p: Vector2, v: Vector2) -> PackedVector2Array:
	var nv: Vector2 = v + _accel(p) * DT
	var np: Vector2 = p + nv * DT
	return PackedVector2Array([np, nv])


## "" = sigue volando; "mars", "earth", "obstacle", "out".
func _check(p: Vector2, step: int) -> String:
	if p.distance_to(MARS_C) < MARS_R:
		return "mars"
	if step > 5 and p.distance_to(EARTH_C) < EARTH_R:
		return "earth"
	for o in _obstacles:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + 6.0:
			return "obstacle"
	if p.x < -100.0 or p.x > W + 120.0 or p.y < -150.0 or p.y > H + 180.0:
		return "out"
	return ""


func _launch_vel() -> Vector2:
	return (ANCHOR - _pull_pos) * K * power


func _physics_process(_delta: float) -> void:
	if _state != State.FLYING:
		return
	var res: PackedVector2Array = _step(_pos, _vel)
	_pos = res[0]
	_vel = res[1]
	_t += DT
	_steps += 1
	if _steps % 2 == 0:
		_trail.append(_pos)
	var why: String = _check(_pos, _steps)
	if why == "" and _t > 25.0:
		why = "out"
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
	queue_redraw()


func _end_flight(why: String) -> void:
	_state = State.RESULT
	_success = why == "mars"
	match why:
		"mars":
			_result_title = "¡LLEGASTE A MARTE!"
			_result_sub = "Tiempo de vuelo: %.1f s" % _t
			_burst(MARS_C, AresUI.TEAL, 40)
		"earth":
			_result_title = "LA NAVE CAYÓ A LA TIERRA"
			_result_sub = "No alcanzó la velocidad de escape. Estira más la resortera."
			_burst(_pos, AresUI.AMBER, 36)
		"obstacle":
			_result_title = "IMPACTO CON DESECHOS"
			_result_sub = "Corrige el ángulo para esquivar los escombros."
			_burst(_pos, AresUI.AMBER, 36)
		_:
			_result_title = "NAVE PERDIDA EN EL ESPACIO"
			_result_sub = "Te pasaste de Marte. Ajusta potencia y ángulo."
	_btn_retry.visible = practice and not _success


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
	draw_string(font, Vector2(330, 700), "TIERRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AresUI.TEAL)

	# Marte y su zona de gravedad
	draw_arc(MARS_C, MARS_R + 46.0, 0.0, TAU, 64, Color(AresUI.AMBER, 0.30), 2.0)
	draw_circle(MARS_C, MARS_R, Color("a4482f"))
	draw_circle(MARS_C + Vector2(-14, -10), 11.0, Color("8a3a26"))
	draw_circle(MARS_C + Vector2(16, 14), 8.0, Color("8a3a26"))
	draw_arc(MARS_C, MARS_R, 0.0, TAU, 64, AresUI.AMBER, 2.0)
	draw_string(font, MARS_C + Vector2(-26, -MARS_R - 12.0), "MARTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AresUI.AMBER)

	# Desechos
	for o in _obstacles:
		var oc: Vector2 = Vector2(o.x, o.y)
		draw_circle(oc, o.z, Color("4a5560"))
		draw_circle(oc + Vector2(-5, -4), o.z * 0.35, Color("38424b"))
		draw_arc(oc, o.z, 0.0, TAU, 32, AresUI.MUTED, 2.0)

	_draw_tower()

	# Estela del vuelo
	if _trail.size() >= 2:
		draw_polyline(_trail, Color(AresUI.TEAL, 0.55), 2.0)

	# Trayectoria guiada
	if _pulling and (ANCHOR - _pull_pos).length() >= PMIN:
		_draw_preview()

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


func _draw_tower() -> void:
	var tower: PackedVector2Array = PackedVector2Array([
		Vector2(172, 674), Vector2(228, 674), Vector2(214, 560), Vector2(186, 560)])
	draw_colored_polygon(tower, AresUI.BG_PANEL)
	draw_polyline(PackedVector2Array([tower[0], tower[3], tower[2], tower[1]]), AresUI.BORDER, 2.0)
	# Travesaños
	draw_line(Vector2(178, 640), Vector2(222, 640), AresUI.BORDER, 2.0)
	draw_line(Vector2(182, 600), Vector2(218, 600), AresUI.BORDER, 2.0)
	# Plataforma y postes de la resortera
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


func _draw_preview() -> void:
	var p: Vector2 = ANCHOR
	var v: Vector2 = _launch_vel()
	var n: int = int(preview_seconds / DT)
	for i in n:
		var res: PackedVector2Array = _step(p, v)
		p = res[0]
		v = res[1]
		var why: String = _check(p, i)
		if why != "":
			draw_arc(p, 9.0, 0.0, TAU, 20, Color(AresUI.AMBER, 0.9), 2.0)
			break
		if i % 4 == 0:
			var f: float = 1.0 - float(i) / float(n)
			draw_circle(p, 2.0 + 3.0 * f, Color(AresUI.TEAL, 0.25 + 0.65 * f))


func _draw_hud(font: Font) -> void:
	draw_string(font, Vector2(28, 38), "SIMULACIÓN DE LANZAMIENTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AresUI.AMBER)
	var hint: String = "Arrastra el cohete hacia atrás, apunta con la guía y suelta."
	if _state == State.FLYING:
		hint = "En vuelo..."
	elif _state == State.RESULT:
		hint = "Resultado del intento."
	draw_string(font, Vector2(28, 62), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AresUI.MUTED)
	draw_string(font, Vector2(28, 86), "INTENTO %d%s" % [_attempts, "" if practice else "  ·  ÚNICO"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AresUI.MUTED)

	if _pulling:
		var lv: Vector2 = _launch_vel()
		var pct: int = int(round((ANCHOR - _pull_pos).length() / PMAX * 100.0))
		var deg: int = int(round(rad_to_deg(-lv.angle())))
		draw_string(font, Vector2(28, 118), "POTENCIA  %d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AresUI.TEAL)
		draw_string(font, Vector2(28, 140), "ÁNGULO    %d°" % deg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AresUI.TEAL)
	elif _state == State.FLYING:
		draw_string(font, Vector2(28, 118), "T+ %.1f s" % _t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AresUI.TEAL)
		draw_string(font, Vector2(28, 140), "DIST. A MARTE  %d" % int(_pos.distance_to(MARS_C)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AresUI.TEAL)

	if _state == State.RESULT:
		var box := Rect2(Vector2(W * 0.5 - 330.0, 250.0), Vector2(660.0, 130.0))
		var accent: Color = AresUI.TEAL if _success else AresUI.AMBER
		draw_rect(box, Color(AresUI.BG_PANEL, 0.94))
		draw_rect(box, accent, false, 2.0)
		draw_string(font, box.position + Vector2(0, 54), _result_title,
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 30, accent)
		draw_string(font, box.position + Vector2(0, 94), _result_sub,
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 14, AresUI.MUTED)
