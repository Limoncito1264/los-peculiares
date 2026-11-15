class_name EndingCutscene
extends Control
## Cinemáticas finales con fade-out a negro y escenas animadas dibujadas en tiempo real:
## - "victory"   : Aterrizaje suave junto a la base marciana.
## - "crash"     : Nave estrellada en Marte y astronauta de espaldas contemplándola.
## - "explosion" : Restos destruidos de la nave flotando en el espacio.
## - "missed"    : La nave pasa de largo frente a Marte abandonando al astronauta.
## - "timeout"   : Astronauta en Marte mirando el calendario tras superar el Sol 60.

const W: float = 1280.0
const H: float = 720.0

var ending_type: String = "victory"
var sub_detail: String = ""

var _t: float = 0.0
var _fade_in: float = 1.0 # 1.0 = negro total, baja a 0.0 para revelar la escena
var _stars: PackedVector2Array = PackedVector2Array()
var _debris: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
var _scale: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _btn_restart: Button
var _btn_menu: Button


static func play(host: Node, type: String, detail: String = "") -> EndingCutscene:
	var tree := host.get_tree() if host else null
	var parent: Node = tree.root if (tree and tree.root) else host
	if parent.has_node("EndingCutsceneLayer"):
		return parent.get_node("EndingCutsceneLayer").get_child(0) as EndingCutscene
	var layer := CanvasLayer.new()
	layer.name = "EndingCutsceneLayer"
	layer.layer = 120
	var c := EndingCutscene.new()
	c.name = "EndingCutscene"
	c.ending_type = type
	c.sub_detail = detail
	layer.add_child(c)
	parent.add_child(layer)
	return c


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 110:
		_stars.append(Vector2(rng.randf_range(0.0, W), rng.randf_range(0.0, H)))

	for i in 18:
		var ang := rng.randf_range(0.0, TAU)
		var spd := rng.randf_range(8.0, 34.0)
		_debris.append({
			"pos": Vector2(W * 0.5 + rng.randf_range(-140.0, 140.0), H * 0.44 + rng.randf_range(-90.0, 90.0)),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"rot": rng.randf_range(0.0, TAU),
			"vrot": rng.randf_range(-1.2, 1.2),
			"size": rng.randf_range(8.0, 26.0),
			"spark": i % 3 == 0,
		})

	for i in 24:
		_smoke.append({
			"off": rng.randf_range(0.0, 6.0),
			"dx": rng.randf_range(-18.0, 18.0),
			"r": rng.randf_range(10.0, 24.0),
		})

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	btn_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 44)
	btn_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(btn_row)

	_btn_menu = AresUI.button("MENÚ PRINCIPAL", "ghost", 46)
	_btn_menu.custom_minimum_size = Vector2(220, 46)
	_btn_menu.modulate.a = 0.0
	_btn_menu.visible = false
	_btn_menu.pressed.connect(_on_main_menu)
	if SoundManager:
		SoundManager.play("victory" if ending_type == "victory" else "gameover", -2.0)
	btn_row.add_child(_btn_menu)

	_btn_restart = AresUI.button("NUEVA PARTIDA", "teal" if ending_type == "victory" else "primary", 46)
	_btn_restart.custom_minimum_size = Vector2(230, 46)
	_btn_restart.modulate.a = 0.0
	_btn_restart.visible = false
	_btn_restart.pressed.connect(_on_restart)
	btn_row.add_child(_btn_restart)


func _cleanup_overlay() -> SceneTree:
	if GameManager and GameManager.has_method("reset_game"):
		GameManager.reset_game()
	var tree := get_tree()
	var p := get_parent()
	if p is CanvasLayer:
		p.queue_free()
	else:
		queue_free()
	return tree


func _on_main_menu() -> void:
	var tree := _cleanup_overlay()
	if tree:
		tree.change_scene_to_file("res://scenes/menu/MenuPrincipal.tscn")


func _on_restart() -> void:
	var tree := _cleanup_overlay()
	if tree:
		tree.reload_current_scene()


func _process(delta: float) -> void:
	_t += delta
	# Primero 0.55s en negro (fade out completado), luego revela escena en 1.1s
	if _t > 0.45:
		_fade_in = maxf(0.0, _fade_in - delta * 0.95)
	for d in _debris:
		d["pos"] += d["vel"] * delta
		d["rot"] += d["vrot"] * delta

	if _t > 3.2:
		var btn_a := minf(1.0, (_t - 3.2) * 1.4)
		_btn_menu.visible = true
		_btn_menu.modulate.a = btn_a
		_btn_restart.visible = true
		_btn_restart.modulate.a = btn_a

	queue_redraw()


func _update_layout() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0 and size != vp_size:
		size = vp_size
	_scale = minf(size.x / W, size.y / H)
	_offset = (size - Vector2(W, H) * _scale) * 0.5


func _draw() -> void:
	_update_layout()
	var font: Font = ThemeDB.fallback_font

	draw_rect(Rect2(Vector2.ZERO, size), Color("#05080c"))
	draw_set_transform(_offset, 0.0, Vector2(_scale, _scale))

	match ending_type:
		"victory":
			_draw_victory(font)
		"crash":
			_draw_crash(font)
		"explosion":
			_draw_explosion(font)
		"missed":
			_draw_missed(font)
		"timeout":
			_draw_timeout(font)

	_draw_narrative_overlay(font)

	# Telón de fade desde negro
	if _fade_in > 0.001:
		draw_rect(Rect2(Vector2(-200, -200), Vector2(W + 400, H + 400)), Color(0.02, 0.03, 0.05, _fade_in))


# ------------------------------------------------------------------
# 1. VICTORIA: Aterrizaje junto a la base marciana
# ------------------------------------------------------------------
func _draw_victory(font: Font) -> void:
	_draw_mars_sky_and_ground(Color("#121a24"), Color("#3b1c14"), Color("#6d3122"))

	# Base marciana a la izquierda
	var base_x := 360.0
	var ground_y := 545.0
	# Domo principal y módulo hábitat
	draw_arc(Vector2(base_x, ground_y), 115.0, PI, TAU, 48, Color("#5ce1e6", 0.55), 3.0)
	draw_rect(Rect2(Vector2(base_x - 115.0, ground_y - 42.0), Vector2(230.0, 42.0)), Color("#1a2632"))
	draw_rect(Rect2(Vector2(base_x - 115.0, ground_y - 42.0), Vector2(230.0, 42.0)), AresUI.TEAL, false, 2.0)
	# Ventanas iluminadas cálidas de la base
	for wx in [base_x - 75.0, base_x - 25.0, base_x + 25.0, base_x + 75.0]:
		draw_rect(Rect2(Vector2(wx - 12.0, ground_y - 28.0), Vector2(24.0, 14.0)), Color("#f4b860", 0.85))
	# Antena de comunicaciones
	draw_line(Vector2(base_x - 85.0, ground_y - 42.0), Vector2(base_x - 85.0, ground_y - 125.0), AresUI.TEAL, 2.5)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	draw_circle(Vector2(base_x - 85.0, ground_y - 128.0), 4.0 + pulse * 3.0, Color(AresUI.TEAL, 0.8))

	# Astronauta esperando junto a la base (saludo sutil)
	_draw_astronaut_back(Vector2(base_x + 155.0, ground_y), 1.0, false)

	# Cohete descendiendo suavemente hasta posarse en x = 790
	var land_progress := clampf((_t - 0.5) / 3.4, 0.0, 1.0)
	var ease_p := 1.0 - pow(1.0 - land_progress, 3.0)
	var rocket_y := lerpf(130.0, ground_y - 54.0, ease_p)
	var rx := 790.0

	# Polvo marciano al tocar suelo
	if land_progress > 0.72:
		var dust_a := clampf((land_progress - 0.72) / 0.28, 0.0, 1.0) * (0.45 + 0.15 * sin(_t * 8.0))
		draw_circle(Vector2(rx - 38.0, ground_y - 6.0), 26.0 * land_progress, Color("#8c4430", dust_a))
		draw_circle(Vector2(rx + 38.0, ground_y - 6.0), 26.0 * land_progress, Color("#8c4430", dust_a))

	# Patas de aterrizaje
	draw_line(Vector2(rx - 14.0, rocket_y + 28.0), Vector2(rx - 32.0, rocket_y + 54.0), AresUI.AMBER, 3.0)
	draw_line(Vector2(rx + 14.0, rocket_y + 28.0), Vector2(rx + 32.0, rocket_y + 54.0), AresUI.AMBER, 3.0)

	# Retropropulsor encendido durante el descenso
	if land_progress < 0.98:
		var fl_h := 28.0 + randf() * 14.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(rx - 10.0, rocket_y + 34.0),
			Vector2(rx + 10.0, rocket_y + 34.0),
			Vector2(rx, rocket_y + 34.0 + fl_h)
		]), AresUI.AMBER)

	# Fuselaje vertical del cohete
	draw_colored_polygon(PackedVector2Array([
		Vector2(rx, rocket_y - 46.0),
		Vector2(rx + 16.0, rocket_y - 16.0),
		Vector2(rx + 16.0, rocket_y + 34.0),
		Vector2(rx - 16.0, rocket_y + 34.0),
		Vector2(rx - 16.0, rocket_y - 16.0),
	]), AresUI.TEXT)
	draw_circle(Vector2(rx, rocket_y - 6.0), 5.0, AresUI.TEAL)
	draw_string(font, Vector2(base_x - 75.0, ground_y + 28.0), "BASE ARES · SECTOR 04", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AresUI.TEAL)


# ------------------------------------------------------------------
# 2. CRASH: Nave estrellada en Marte y astronauta de espaldas
# ------------------------------------------------------------------
func _draw_crash(_font: Font) -> void:
	_draw_mars_sky_and_ground(Color("#160e0e"), Color("#361812"), Color("#5c281c"))
	var ground_y := 550.0

	# Cráter de impacto a la derecha
	draw_arc(Vector2(820.0, ground_y + 8.0), 120.0, PI, TAU, 40, Color("#240e0a"), 14.0)

	# Fuselaje partido y clavado en ángulo en la arena marciana
	var xf1 := Transform2D(0.58, Vector2(790.0, ground_y - 18.0))
	draw_colored_polygon(PackedVector2Array([
		xf1 * Vector2(-42, -16), xf1 * Vector2(28, -14),
		xf1 * Vector2(22, 16), xf1 * Vector2(-42, 16)
	]), Color("#b8c0c8"))
	draw_colored_polygon(PackedVector2Array([
		xf1 * Vector2(-42, -16), xf1 * Vector2(-56, -28), xf1 * Vector2(-52, -14)
	]), Color("#9c4434"))

	# Punta del cohete desprendida más adelante
	var xf2 := Transform2D(-0.42, Vector2(915.0, ground_y - 4.0))
	draw_colored_polygon(PackedVector2Array([
		xf2 * Vector2(36, 0), xf2 * Vector2(0, -14), xf2 * Vector2(0, 14)
	]), Color("#9aa4ae"))

	# Humo oscuro subiendo lentamente de los restos
	for s in _smoke:
		var off: float = s["off"]
		var dx: float = s["dx"]
		var rad: float = s["r"]
		var cycle: float = fmod(_t * 0.55 + off, 3.0) / 3.0
		var sy: float = (ground_y - 26.0) - cycle * 165.0
		var sx: float = 805.0 + dx * (0.5 + cycle * 1.6) + sin(_t + off) * 8.0
		var alpha: float = (1.0 - cycle) * 0.34
		draw_circle(Vector2(sx, sy), rad * (0.7 + cycle * 0.9), Color(0.18, 0.16, 0.16, alpha))

	# Astronauta de espaldas (sin mostrar rostro), quieto observando los restos
	_draw_astronaut_back(Vector2(430.0, ground_y + 4.0), 1.35, true)


# ------------------------------------------------------------------
# 3. EXPLOSION: Nave destruida flotando en el espacio
# ------------------------------------------------------------------
func _draw_explosion(_font: Font) -> void:
	for s in _stars:
		draw_circle(s, 1.5, Color(AresUI.TEXT, 0.45))

	# Tierra y Marte distantes
	draw_circle(Vector2(140.0, 620.0), 130.0, Color("#12302f"))
	draw_arc(Vector2(140.0, 620.0), 130.0, 0.0, TAU, 64, Color(AresUI.TEAL, 0.4), 2.0)
	draw_circle(Vector2(1130.0, 160.0), 34.0, Color("#7c3422"))

	# Resplandor residual de la explosión
	var glow := maxf(0.0, 0.32 - _t * 0.04)
	if glow > 0.0:
		draw_circle(Vector2(W * 0.5, H * 0.44), 190.0, Color("#E05A47", glow))

	# Fragmentos del casco, paneles y chispas flotando a la deriva
	for d in _debris:
		var p: Vector2 = d["pos"]
		var sz: float = d["size"]
		var xf := Transform2D(d["rot"], p)
		var poly := PackedVector2Array([
			xf * Vector2(-sz, -sz * 0.45),
			xf * Vector2(sz * 0.8, -sz * 0.6),
			xf * Vector2(sz, sz * 0.35),
			xf * Vector2(-sz * 0.5, sz * 0.55),
		])
		draw_colored_polygon(poly, Color("#6b7682"))
		draw_polyline(poly, Color("#9aa6b2"), 1.5)
		if d["spark"]:
			var rot: float = d["rot"]
			var flick: float = 0.4 + 0.6 * sin(_t * 14.0 + rot)
			draw_circle(p, 3.0, Color(AresUI.AMBER, flick))


# ------------------------------------------------------------------
# 4. MISSED: La nave pasa de largo junto a Marte hacia el vacío
# ------------------------------------------------------------------
func _draw_missed(_font: Font) -> void:
	for s in _stars:
		draw_circle(s, 1.5, Color(AresUI.TEXT, 0.45))

	# Marte grande en primer plano abajo a la derecha (inalcanzable)
	var mars_c := Vector2(960.0, 520.0)
	draw_circle(mars_c, 220.0, Color("#8a3925"))
	draw_circle(mars_c + Vector2(-60, -45), 42.0, Color("#6f2b1b"))
	draw_circle(mars_c + Vector2(50, 35), 34.0, Color("#6f2b1b"))
	draw_arc(mars_c, 220.0, 0.0, TAU, 96, Color(AresUI.AMBER, 0.55), 3.0)

	# Trayectoria de la nave alejándose en diagonal hacia la esquina superior izquierda
	var prog := clampf(_t / 6.5, 0.0, 1.0)
	var start_p := Vector2(780.0, 310.0)
	var end_p := Vector2(180.0, 85.0)
	var ship_p := start_p.lerp(end_p, prog)
	var ship_scale := lerpf(1.0, 0.25, prog)

	# Estela tenue que se pierde
	draw_line(start_p, ship_p, Color(AresUI.TEAL, 0.28), 2.0)

	# Cohete pequeño alejándose sin combustible
	var ang := (end_p - start_p).angle()
	var xf := Transform2D(ang, ship_p).scaled_local(Vector2(ship_scale, ship_scale))
	draw_colored_polygon(PackedVector2Array([
		xf * Vector2(22, 0), xf * Vector2(8, -7), xf * Vector2(-16, -7),
		xf * Vector2(-16, 7), xf * Vector2(8, 7)
	]), AresUI.TEXT)


# ------------------------------------------------------------------
# 5. TIMEOUT: Interior de la base marciana mirando el calendario (> Sol 60)
# ------------------------------------------------------------------
func _draw_timeout(font: Font) -> void:
	var floor_y := 602.0

	# 1. Mamparo y paredes interiores del hábitat presurizado
	draw_rect(Rect2(Vector2(0, 0), Vector2(W, floor_y)), Color("#0f151d"))
	# Paneles estructurales verticales del módulo
	for px in [110.0, 560.0, 1080.0]:
		draw_rect(Rect2(Vector2(px, 140.0), Vector2(18.0, floor_y - 140.0)), Color("#17202b"))
		draw_line(Vector2(px, 140.0), Vector2(px, floor_y), Color("#243140"), 1.5)
		draw_line(Vector2(px + 18.0, 140.0), Vector2(px + 18.0, floor_y), Color("#243140"), 1.5)

	# Tuberías superiores de soporte vital y cableado
	draw_line(Vector2(0, 172.0), Vector2(W, 172.0), Color("#263342"), 7.0)
	draw_line(Vector2(0, 184.0), Vector2(W, 184.0), Color("#1c2631"), 4.0)
	draw_line(Vector2(0, 192.0), Vector2(W, 192.0), Color("#7a3e26", 0.65), 3.0)

	# 2. Gran escotilla circular reforzada (cielo y suelo recortados con anillo exterior)
	var win_c := Vector2(335.0, 335.0)
	var win_r := 132.0

	# Cielo de Marte de día (arriba): tono caramelo/arena pálido
	draw_rect(Rect2(Vector2(win_c.x - 140.0, win_c.y - 140.0), Vector2(280.0, 155.0)), Color("#e3be96"))
	# Franja de horizonte luminoso
	draw_rect(Rect2(Vector2(win_c.x - 140.0, win_c.y - 12.0), Vector2(280.0, 28.0)), Color("#edd0ae"))

	# Montañas marcianas lejanas (triángulos simples convexos que nunca fallan)
	draw_colored_polygon(PackedVector2Array([
		Vector2(win_c.x - 140.0, win_c.y + 16.0),
		Vector2(win_c.x - 55.0, win_c.y - 22.0),
		Vector2(win_c.x + 25.0, win_c.y + 16.0),
	]), Color("#9c4926"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(win_c.x - 25.0, win_c.y + 16.0),
		Vector2(win_c.x + 32.0, win_c.y - 34.0),
		Vector2(win_c.x + 140.0, win_c.y + 16.0),
	]), Color("#8a3d1e"))

	# Suelo de Marte (abajo): terracota rojizo oscuro bien contrastado con el cielo
	draw_rect(Rect2(Vector2(win_c.x - 140.0, win_c.y + 14.0), Vector2(280.0, 130.0)), Color("#a64522"))
	# Línea de horizonte nítida
	draw_line(Vector2(win_c.x - 140.0, win_c.y + 14.0), Vector2(win_c.x + 140.0, win_c.y + 14.0), Color("#6e2912"), 2.5)
	# Franja de terreno más cercana y oscura
	draw_rect(Rect2(Vector2(win_c.x - 140.0, win_c.y + 56.0), Vector2(280.0, 90.0)), Color("#782e15"))

	# Rocas oscuras marcianas sobre el suelo
	var dark_rocks := [
		[Vector2(-72, 46), 11.0], [Vector2(-58, 52), 6.0], [Vector2(-24, 68), 9.0],
		[Vector2(18, 52), 8.0], [Vector2(48, 76), 10.0], [Vector2(66, 36), 6.5],
		[Vector2(-12, 24), 5.0], [Vector2(28, 22), 4.5], [Vector2(-46, 28), 5.5],
	]
	for rk in dark_rocks:
		var rp: Vector2 = win_c + rk[0]
		var rs: float = rk[1]
		draw_colored_polygon(PackedVector2Array([
			rp + Vector2(-rs, rs * 0.4),
			rp + Vector2(-rs * 0.5, -rs * 0.6),
			rp + Vector2(rs * 0.4, -rs * 0.65),
			rp + Vector2(rs * 0.9, rs * 0.35),
		]), Color("#2b1912"))

	# Máscara circular del color de la pared (#0f151d) para recortar lo que salga del círculo
	draw_arc(win_c, win_r + 36.0, 0.0, TAU, 96, Color("#0f151d"), 72.0)

	# Reflejo sutil del cristal presurizado
	draw_arc(win_c, win_r - 12.0, -2.3, -1.5, 20, Color(1.0, 1.0, 1.0, 0.25), 4.0)

	# Marco metálico grueso de la escotilla con remaches
	draw_arc(win_c, win_r + 5.0, 0.0, TAU, 72, Color("#283442"), 12.0)
	draw_arc(win_c, win_r - 1.0, 0.0, TAU, 72, Color("#455669"), 2.5)
	draw_arc(win_c, win_r + 11.0, 0.0, TAU, 72, Color("#131a22"), 2.5)
	for r_i in 12:
		var ra := float(r_i) * (TAU / 12.0)
		var rp := win_c + Vector2(cos(ra), sin(ra)) * (win_r + 5.0)
		draw_circle(rp, 2.2, Color("#63768c"))

	# 3. Consola de telemetría y soporte vital bajo la ventana (izquierda)
	var desk := Rect2(Vector2(155.0, 502.0), Vector2(355.0, floor_y - 502.0))
	draw_rect(desk, Color("#18212c"))
	draw_rect(desk, Color("#2f3e4f"), false, 2.0)
	# Monitores sobre la consola
	var mon1 := Rect2(Vector2(178.0, 444.0), Vector2(138.0, 58.0))
	draw_rect(mon1, Color("#0b1016"))
	draw_rect(mon1, Color("#3a4b5e"), false, 2.5)
	draw_string(font, mon1.position + Vector2(10, 22), "ENLACE TIERRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AresUI.MUTED)
	draw_string(font, mon1.position + Vector2(10, 42), "SIN VENTANA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E05A47"))

	var mon2 := Rect2(Vector2(332.0, 454.0), Vector2(118.0, 48.0))
	draw_rect(mon2, Color("#0b1016"))
	draw_rect(mon2, Color("#3a4b5e"), false, 2.5)
	# Línea plana de telemetría orbital
	draw_line(mon2.position + Vector2(10, 26), mon2.position + Vector2(108, 26), Color("#E05A47", 0.85), 2.0)
	# Botones y luces de estado en el panel frontal de la consola
	for b_i in 8:
		var bx := 180.0 + b_i * 38.0
		var bcol := Color("#E05A47") if b_i % 3 == 0 else AresUI.AMBER
		draw_rect(Rect2(Vector2(bx, 520.0), Vector2(22.0, 10.0)), Color(bcol, 0.65))
	# Rejillas de ventilación de la consola
	for v_i in 5:
		draw_line(Vector2(180.0, 548.0 + v_i * 8.0), Vector2(485.0, 548.0 + v_i * 8.0), Color("#10161e"), 3.0)

	# 4. Cajas de suministros y tanque de oxígeno a la derecha
	var crate1 := Rect2(Vector2(1065.0, 528.0), Vector2(115.0, floor_y - 528.0))
	draw_rect(crate1, Color("#1f2a36"))
	draw_rect(crate1, Color("#38495c"), false, 2.0)
	draw_line(Vector2(crate1.position.x, crate1.position.y + 18.0), Vector2(crate1.end.x, crate1.position.y + 18.0), AresUI.AMBER, 3.0)
	draw_string(font, crate1.position + Vector2(12, 44), "RACIONES", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AresUI.MUTED)

	# Cilindro de oxígeno junto al mamparo derecho
	draw_rect(Rect2(Vector2(1198.0, 485.0), Vector2(34.0, floor_y - 485.0)), Color("#293847"))
	draw_rect(Rect2(Vector2(1198.0, 485.0), Vector2(34.0, floor_y - 485.0)), AresUI.TEAL, false, 1.5)
	draw_rect(Rect2(Vector2(1208.0, 473.0), Vector2(14.0, 12.0)), Color("#5a6c80"))

	# 5. Gran calendario de misión colgado en el mamparo frente al astronauta
	var cal := Rect2(Vector2(755.0, 210.0), Vector2(245.0, 260.0))
	# Sombra del tablero en la pared
	draw_rect(Rect2(cal.position + Vector2(6, 8), cal.size), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(cal, Color("#161f29"))
	draw_rect(cal, AresUI.AMBER, false, 2.5)
	draw_rect(Rect2(cal.position, Vector2(cal.size.x, 44.0)), Color("#8c2d23"))
	draw_string(font, cal.position + Vector2(0, 29), "VENTANA ORBITAL", HORIZONTAL_ALIGNMENT_CENTER, cal.size.x, 15, AresUI.TEXT)
	draw_string(font, cal.position + Vector2(0, 108), "SOL %d" % maxi(61, GameManager.current_sol if GameManager else 61),
		HORIZONTAL_ALIGNMENT_CENTER, cal.size.x, 42, Color("#E05A47"))
	draw_string(font, cal.position + Vector2(0, 150), "LÍMITE: SOL 60",
		HORIZONTAL_ALIGNMENT_CENTER, cal.size.x, 13, AresUI.MUTED)

	# Cuadrícula de días tachados en el calendario
	for row in 3:
		for col_i in 5:
			var cx := cal.position.x + 26.0 + col_i * 42.0
			var cy := cal.position.y + 174.0 + row * 24.0
			draw_line(Vector2(cx, cy), Vector2(cx + 22.0, cy + 14.0), Color("#E05A47", 0.75), 2.0)
			draw_line(Vector2(cx + 22.0, cy), Vector2(cx, cy + 14.0), Color("#E05A47", 0.75), 2.0)

	# 6. Suelo metálico antideslizante del módulo y astronauta de espaldas
	draw_rect(Rect2(Vector2(0, floor_y), Vector2(W, H - floor_y)), Color("#0a0e14"))
	draw_line(Vector2(0, floor_y), Vector2(W, floor_y), Color("#384859"), 3.0)
	for g_i in 18:
		var gx := 40.0 + g_i * 70.0
		draw_line(Vector2(gx, floor_y + 6.0), Vector2(gx - 18.0, floor_y + 24.0), Color("#18212b"), 2.0)

	# Sombra proyectada del astronauta en el suelo de la base
	draw_colored_polygon(PackedVector2Array([
		Vector2(620.0, floor_y + 2.0), Vector2(685.0, floor_y + 2.0),
		Vector2(705.0, floor_y + 14.0), Vector2(605.0, floor_y + 14.0)
	]), Color(0.0, 0.0, 0.0, 0.45))

	_draw_astronaut_back(Vector2(650.0, floor_y), 1.48, true)


# ------------------------------------------------------------------
# Helpers visuales
# ------------------------------------------------------------------
func _draw_mars_sky_and_ground(sky: Color, horizon: Color, ground: Color) -> void:
	draw_rect(Rect2(Vector2(0, 0), Vector2(W, 545.0)), sky)
	for s in _stars:
		if s.y < 510.0:
			draw_circle(s, 1.3, Color(AresUI.TEXT, 0.35))
	draw_rect(Rect2(Vector2(0, 500.0), Vector2(W, 60.0)), horizon)
	draw_rect(Rect2(Vector2(0, 545.0), Vector2(W, H - 545.0)), ground)
	draw_line(Vector2(0, 545.0), Vector2(W, 545.0), Color(AresUI.AMBER, 0.45), 2.0)


func _draw_astronaut_back(feet: Vector2, sc: float, slumped: bool) -> void:
	# Silueta de espaldas del astronauta (mochila PLSS, traje blanco/gris, casco con visera lateral sin cara)
	var xf := Transform2D(0.0, feet).scaled_local(Vector2(sc, sc))
	var head_y := -74.0 if slumped else -80.0
	# Piernas
	draw_rect(Rect2(xf * Vector2(-12, -36), Vector2(9 * sc, 36 * sc)), Color("#cfd6de"))
	draw_rect(Rect2(xf * Vector2(3, -36), Vector2(9 * sc, 36 * sc)), Color("#cfd6de"))
	# Torso y mochila soporte vital
	draw_rect(Rect2(xf * Vector2(-16, -68), Vector2(32 * sc, 34 * sc)), Color("#dce2e8"))
	draw_rect(Rect2(xf * Vector2(-12, -65), Vector2(24 * sc, 26 * sc)), Color("#8a96a3"))
	draw_rect(Rect2(xf * Vector2(-12, -65), Vector2(24 * sc, 26 * sc)), AresUI.BORDER, false, 1.5)
	# Casco de espaldas (sin rostro visible)
	draw_circle(xf * Vector2(0, head_y), 14.0 * sc, Color("#e6ecf2"))
	draw_arc(xf * Vector2(0, head_y), 14.0 * sc, -0.4, 0.4, 12, AresUI.AMBER, 2.5)


func _draw_narrative_overlay(font: Font) -> void:
	var alpha := clampf((_t - 1.5) / 1.2, 0.0, 1.0)
	if alpha <= 0.01:
		return

	var title := ""
	var body := ""
	var tag := ""
	var accent := AresUI.AMBER

	match ending_type:
		"victory":
			tag = "ENLACE DE RESCATE · MARTE"
			title = "LO LOGRASTE · FUISTE RESCATADO"
			body = "La nave aterrizó intacta junto a tu base dentro de la ventana de 60 Soles. No estabas solo."
			accent = AresUI.TEAL
		"crash":
			tag = "TELEMETRÍA DE IMPACTO · SUPERFICIE MARCIANA"
			title = "FIN DE LA PARTIDA · NAVE ESTRELLADA"
			body = "Entraste a Marte con demasiada velocidad. Sin nave de retorno, solo queda el silencio rojo."
			accent = Color("#E05A47")
		"explosion":
			tag = "ALERTA CRÍTICA · PÉRDIDA DE VEHÍCULO"
			title = "FIN DE LA PARTIDA · NAVE DESTRUIDA"
			body = sub_detail if sub_detail != "" else "La estructura colapsó antes de alcanzar Marte."
			accent = Color("#E05A47")
		"missed":
			tag = "ÓRBITA PERDIDA · ESPACIO PROFUNDO"
			title = "FIN DE LA PARTIDA · ABANDONADO EN MARTE"
			body = "La nave pasó de largo frente al planeta sin lograr inserción orbital y se perdió para siempre."
			accent = AresUI.AMBER
		"timeout":
			tag = "PLAZO ORBITAL EXPIRADO · SOL 60 SUPERADO"
			title = "FIN DE LA PARTIDA · VENTANA CERRADA"
			body = "Pasaron los 60 Soles sin despegar. La Tierra y Marte se alejaron hasta la próxima conjunción."
			accent = AresUI.AMBER

	# Banda superior sutil para legibilidad
	draw_rect(Rect2(Vector2(0, 0), Vector2(W, 155.0)), Color(0.03, 0.05, 0.08, 0.82 * alpha))
	draw_string(font, Vector2(44, 42), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(accent, alpha))
	draw_string(font, Vector2(44, 84), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(AresUI.TEXT, alpha))
	draw_string(font, Vector2(44, 118), body, HORIZONTAL_ALIGNMENT_LEFT, W - 88.0, 15, Color(AresUI.MUTED, alpha))

	if GameManager:
		var stats := "SOL ALCANZADO: %d / %d   ·   SISTEMAS FABRICADOS: %d / %d" % [
			GameManager.current_sol, GameManager.MAX_SOLS,
			GameManager.systems_ready(), GameManager.ROCKET_PARTS.size()
		]
		draw_string(font, Vector2(44, H - 42.0), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(AresUI.MUTED, alpha))
