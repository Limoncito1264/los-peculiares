extends Control
## Pestaña DISEÑO (Figma 03 · Diseño / Editor de nave).
## Se instancia dentro de ContenedorCentral (ver cockpit_main.gd). Construye su UI por código.

# --- Plano de ensamblaje: retícula + silueta de la nave (placeholder hasta tener los sprites) ---
class Plano extends Control:
	# Orden: fuselaje, motor, depósito, guiado
	var ready_flags: Array[bool] = [false, false, false, false]
	var _tex: ImageTexture

	const SPRITE := [
		"....................................",
		".................OO.................",
		"................OAAO................",
		"................OAaO................",
		"...............OAAAaO...............",
		"...............OAAAaO...............",
		"..............OAAAAaaO..............",
		"..............OAAAAaaO..............",
		".............OAAAAAAaaO.............",
		".............OAAAAAAaaO.............",
		".............OOOOOOOOOO.............",
		".............OWWWWWWSSO.............",
		".............OWWWWWWSSO.............",
		"............OWWWWWWWWSSO............",
		"............OWWWWWWWWSSO............",
		"............OWWOOOOOOWSO............",
		"............OWOgCcCCgOSO............",
		"........OO..OWOCCCCCOOSO..OO........",
		".......OAAO.OWOCCCCgOOSO.OAAO.......",
		".......OAaO.OWWOOOOOOWSO.OAaO.......",
		"......OAAAaOOWWWWWWWWSSOOAAAaO......",
		"......OOOOOOOWWWWWWWWSSOOOOOOO......",
		"......OWWWSSOWWOOOOOOWSOWWWSSO......",
		"......OWOOSSOWOAWWWWgOSOWOOSSO......",
		"......OWOOSSOWWOOOOOOWSOWOOSSO......",
		"......OWWWSSOWWWWWWWWSSOWWWSSO......",
		"......OWWWSSOWWWWWWWWSSOWWWSSO......",
		"......OWWWSSOWWWWWWWWSSOWWWSSO......",
		"......OWOOSSOWWWWWWWWSSOWOOSSO......",
		"......OWWWSSOWOgGGGGgOSOWWWSSO......",
		"......OWWWSSOWWWWWWWWSSOWWWSSO......",
		"......OWWWSSOWWWWWWWWSSOWWWSSO......",
		"......OWWWSSOWWWWWWWWSSOWWWSSO......",
		"......OOOOOOOOOOOOOOOOOOOOOOOO......",
		".....OOGGGGOO.OOGGGGOO.OOGGGGOO.....",
		"....OOGGOOGGOOOGGGGGGOOOGGOOGGOO....",
		"....OGGO..OGGOOGGGGGGOOGGO..OGGO....",
		"....OOOO..OOOOOOOOOOOOOOOO..OOOO....",
		"...............OOAAOO...............",
		"..............OOGGGGOO..............",
		"..............OOOOOOOO..............",
	]

	func _init() -> void:
		custom_minimum_size = Vector2(360, 436)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _generar_textura() -> ImageTexture:
		var pal := {
			"O": Color("#0B111A"),
			"A": Color("#F2B84B"),
			"a": Color("#C48428"),
			"W": Color("#E6ECE8"),
			"S": Color("#9EB0B8"),
			"G": Color("#526880"),
			"g": Color("#7C8FA6"),
			"C": Color("#4CE0B3"),
			"c": Color("#B8FFF0"),
		}
		var h := SPRITE.size()
		var w := 36
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in range(h):
			var row: String = SPRITE[y]
			for x in range(w):
				var ch := row[x]
				if ch != ".":
					var visible := false
					if y <= 10:
						visible = ready_flags[3]
					elif y >= 34 and x >= 14 and x <= 21:
						visible = ready_flags[1]
					elif (y <= 33 and (x <= 11 or x >= 24)) or (y >= 34 and (x <= 13 or x >= 22)):
						visible = ready_flags[2]
					elif y >= 21 and y <= 33 and (x == 12 or x == 23):
						visible = ready_flags[0] or ready_flags[2]
					else:
						visible = ready_flags[0]
					if visible:
						img.set_pixel(x, y, pal[ch])
		return ImageTexture.create_from_image(img)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), AresUI.BG_INSET)
		for x in range(0, int(size.x), 24):
			draw_rect(Rect2(x, 0, 1, size.y), AresUI.GRID)
		for y in range(0, int(size.y), 24):
			draw_rect(Rect2(0, y, size.x, 1), AresUI.GRID)
		_tex = _generar_textura()
		var escala := 6.0
		var tam := Vector2(36.0 * escala, float(SPRITE.size()) * escala)
		var pos := Vector2((size.x - tam.x) * 0.5, (size.y - tam.y) * 0.5 + 4.0)
		draw_texture_rect(_tex, Rect2(pos, tam), false)
		draw_rect(Rect2(Vector2.ZERO, size), AresUI.BORDER, false, 1.0)


var selected: int = 0
var workers: int = 1

var _plano: Plano
var _cards: Array[Button] = []
var _card_state: Array[Label] = []
var _lbl_name: Label
var _rows: GridContainer
var _lbl_workers: Label
var _lbl_dur_title: Label
var _lbl_days: Label
var _lbl_free: Label
var _lbl_free_total: Label
var _btn_minus: Button
var _btn_plus: Button
var _btn_start: Button
var _lbl_status: Label


func _ready() -> void:
	# Fondo del panel
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", AresUI.box(AresUI.BG_PANEL, AresUI.BORDER))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Scroll de seguridad por si ContenedorCentral es más pequeño que el diseño (904x848)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	col.add_child(AresUI.label("03 / FABRICACIÓN DE COMPONENTES", 12, AresUI.AMBER))
	col.add_child(AresUI.label("Tu equipo construye. Tú decides.", 32, AresUI.TEXT, true))
	col.add_child(AresUI.label("Los trabajadores asignados quedan ocupados hasta terminar la pieza.", 14, AresUI.MUTED))
	col.add_child(AresUI.hline())

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 20)
	col.add_child(main)
	main.add_child(_build_plano())
	main.add_child(_build_orden())

	col.add_child(AresUI.label("PIEZAS DEL COHETE", 20, AresUI.TEXT, true))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	col.add_child(cards)
	for i in GameManager.ROCKET_PARTS.size():
		cards.add_child(_build_card(i))

	_lbl_status = AresUI.label("", 12, AresUI.AMBER)
	col.add_child(_lbl_status)

	Events.part_state_changed.connect(_on_part_changed)
	Events.resources_updated.connect(_refresh)
	Events.sol_advanced.connect(_on_sol_advanced)

	select_piece(0)


# ------------------------------------------------------------------
# Construcción de UI
# ------------------------------------------------------------------
func _build_plano() -> Control:
	_plano = Plano.new()
	_plano.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var top := AresUI.label("ODYSSEY-60 / PLANO DE REFERENCIA", 10, AresUI.TEAL)
	top.position = Vector2(15, 13)
	_plano.add_child(top)
	var bottom := AresUI.label("VISTA FRONTAL / DISEÑO OBJETIVO", 10, AresUI.MUTED)
	bottom.position = Vector2(15, 405)
	_plano.add_child(bottom)
	return _plano


func _build_orden() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", AresUI.box(AresUI.BG_INSET, AresUI.BORDER, 17))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(AresUI.label("PIEZA SELECCIONADA", 11, AresUI.AMBER))
	_lbl_name = AresUI.label("", 25, AresUI.TEXT, true)
	v.add_child(_lbl_name)
	v.add_child(AresUI.label("RECETA / KIT ESTÁNDAR DE FABRICACIÓN", 10, AresUI.MUTED))
	v.add_child(AresUI.hline())

	var head := HBoxContainer.new()
	var h1 := AresUI.label("MATERIAL", 10, AresUI.MUTED)
	h1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h2 := AresUI.label("NECESITAS / TIENES", 10, AresUI.MUTED)
	h2.custom_minimum_size = Vector2(190, 0)
	head.add_child(h1)
	head.add_child(h2)
	v.add_child(head)

	_rows = GridContainer.new()
	_rows.columns = 2
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("h_separation", 8)
	_rows.add_theme_constant_override("v_separation", 10)
	v.add_child(_rows)

	v.add_child(AresUI.hline())

	# Trabajadores + duración
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 24)
	v.add_child(mid)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(AresUI.label("TRABAJADORES A ASIGNAR", 10, AresUI.MUTED))
	left.add_child(_build_stepper())
	mid.add_child(left)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(150, 0)
	_lbl_dur_title = AresUI.label("DURACIÓN", 10, AresUI.MUTED)
	right.add_child(_lbl_dur_title)
	_lbl_days = AresUI.label("", 26, AresUI.TEAL, true)
	right.add_child(_lbl_days)
	mid.add_child(right)

	var free_row := HBoxContainer.new()
	var free_t := AresUI.label("DISPONIBLES AHORA", 10, AresUI.MUTED)
	free_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	free_row.add_child(free_t)
	_lbl_free = AresUI.label("", 26, AresUI.TEXT, true)
	free_row.add_child(_lbl_free)
	_lbl_free_total = AresUI.label("", 12, AresUI.MUTED)
	free_row.add_child(_lbl_free_total)
	v.add_child(free_row)

	_btn_start = AresUI.button("INICIAR FABRICACIÓN  >>", "primary")
	_btn_start.pressed.connect(_on_start_pressed)
	v.add_child(_btn_start)
	return panel


func _build_stepper() -> Control:
	var stepper := PanelContainer.new()
	stepper.custom_minimum_size = Vector2(212, 42)
	stepper.add_theme_stylebox_override("panel", AresUI.box(AresUI.BG_PANEL, AresUI.BORDER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	stepper.add_child(row)

	_btn_minus = AresUI.stepper_button("-")
	_btn_minus.pressed.connect(change_workers.bind(-1))
	row.add_child(_btn_minus)

	var mid := HBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 8)
	_lbl_workers = AresUI.label("1", 26, AresUI.TEXT, true)
	mid.add_child(_lbl_workers)
	mid.add_child(AresUI.label("personas", 11, AresUI.MUTED))
	row.add_child(mid)

	_btn_plus = AresUI.stepper_button("+")
	_btn_plus.pressed.connect(change_workers.bind(1))
	row.add_child(_btn_plus)
	return stepper


func _build_card(i: int) -> Control:
	var def: Dictionary = GameManager.ROCKET_PARTS[i]
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 112)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(select_piece.bind(i))

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 13)
	b.add_child(m)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	v.add_child(AresUI.label("%02d" % (i + 1), 11, AresUI.MUTED))
	var name_l := AresUI.label(String(def["name"]), 18, AresUI.TEXT, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(name_l)
	v.add_child(AresUI.spacer())
	var st := AresUI.label("PENDIENTE", 10, AresUI.MUTED)
	v.add_child(st)

	_cards.append(b)
	_card_state.append(st)
	return b


# ------------------------------------------------------------------
# Lógica
# ------------------------------------------------------------------
func select_piece(i: int) -> void:
	selected = i
	_refresh()


func change_workers(delta: int) -> void:
	workers += delta
	_refresh()


func _on_start_pressed() -> void:
	var err: String = GameManager.start_fabrication(selected, workers)
	if err != "":
		_lbl_status.text = err
		_lbl_status.add_theme_color_override("font_color", AresUI.AMBER)
	else:
		_lbl_status.text = "Fabricación iniciada: los trabajadores quedan ocupados hasta terminar la pieza."
		_lbl_status.add_theme_color_override("font_color", AresUI.TEAL)


func _on_part_changed(_index: int) -> void:
	_refresh()


func _on_sol_advanced(_sol: int) -> void:
	_refresh()


func _refresh() -> void:
	if _rows == null:
		return
	var def: Dictionary = GameManager.ROCKET_PARTS[selected]
	var st: int = GameManager.part_state[selected]
	var pending: bool = st == GameManager.PartState.PENDING
	var free: int = GameManager.workers_free()

	_lbl_name.text = String(def["name"])

	# Receta: necesitas / tienes
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var recipe: Dictionary = def["recipe"]
	for key in recipe.keys():
		var info: Array = GameManager.MATERIAL_INFO[key]
		var need: int = int(recipe[key])
		var have: int = int(GameManager.inventory.get(key, 0))
		var n := AresUI.label(String(info[0]), 16, AresUI.TEXT, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows.add_child(n)
		var cell := HBoxContainer.new()
		cell.custom_minimum_size = Vector2(190, 0)
		cell.add_theme_constant_override("separation", 8)
		cell.add_child(AresUI.label("%d %s /" % [need, info[1]], 12, AresUI.AMBER))
		cell.add_child(AresUI.label(str(have), 14, AresUI.TEAL if have >= need else AresUI.TEXT))
		cell.add_child(AresUI.label(String(info[1]), 11, AresUI.MUTED))
		_rows.add_child(cell)

	# Trabajadores
	if pending:
		workers = clampi(workers, 1 if free > 0 else 0, free)
	_lbl_workers.text = str(workers if pending else GameManager.part_workers[selected])
	_btn_minus.disabled = not pending or workers <= 1
	_btn_plus.disabled = not pending or workers >= free
	_lbl_free.text = str(free)
	_lbl_free_total.text = "/ %d" % GameManager.staff_count

	# Duración / estado
	match st:
		GameManager.PartState.PENDING:
			_lbl_dur_title.text = "DURACIÓN"
			_lbl_days.text = ("%d DÍAS" % GameManager.fabrication_days(selected, workers)) if workers > 0 else "—"
		GameManager.PartState.IN_PROGRESS:
			_lbl_dur_title.text = "TIEMPO RESTANTE"
			_lbl_days.text = "%d DÍAS" % ceili(GameManager.part_days_left[selected])
		_:
			_lbl_dur_title.text = "ESTADO"
			_lbl_days.text = "LISTA"

	# Botón principal
	match st:
		GameManager.PartState.PENDING:
			_btn_start.text = "INICIAR FABRICACIÓN  >>"
			_btn_start.disabled = workers < 1
		GameManager.PartState.IN_PROGRESS:
			_btn_start.text = "FABRICANDO..."
			_btn_start.disabled = true
		_:
			_btn_start.text = "PIEZA FABRICADA"
			_btn_start.disabled = true

	# Tarjetas y plano
	var flags: Array[bool] = []
	for i in _cards.size():
		var s: int = GameManager.part_state[i]
		flags.append(s == GameManager.PartState.READY)
		var sb := AresUI.box(AresUI.BG_INSET, AresUI.AMBER if i == selected else AresUI.BORDER)
		for style_name in ["normal", "hover", "pressed"]:
			_cards[i].add_theme_stylebox_override(style_name, sb)
		var lbl := _card_state[i]
		match s:
			GameManager.PartState.IN_PROGRESS:
				lbl.text = "EN CURSO · %d DÍAS" % ceili(GameManager.part_days_left[i])
				lbl.add_theme_color_override("font_color", AresUI.AMBER)
			GameManager.PartState.READY:
				lbl.text = "FABRICADA"
				lbl.add_theme_color_override("font_color", AresUI.TEAL)
			_:
				lbl.text = "PENDIENTE"
				lbl.add_theme_color_override("font_color", AresUI.MUTED)
	_plano.ready_flags = flags
	_plano.queue_redraw()

	# Mensaje por defecto
	if pending and not GameManager.has_materials(selected):
		_lbl_status.text = "Compra y recibe los insumos antes de fabricar."
		_lbl_status.add_theme_color_override("font_color", AresUI.AMBER)
	elif pending:
		_lbl_status.text = "Insumos listos. Asigna trabajadores e inicia la fabricación."
		_lbl_status.add_theme_color_override("font_color", AresUI.TEAL)
	elif st == GameManager.PartState.IN_PROGRESS:
		var motivo: String = GameManager.fabrication_block_reason()
		if motivo != "":
			_lbl_status.text = motivo
			_lbl_status.add_theme_color_override("font_color", AresUI.AMBER)
		else:
			_lbl_status.text = "Fabricando. Avanza un sol para que los trabajadores progresen."
			_lbl_status.add_theme_color_override("font_color", AresUI.TEAL)
