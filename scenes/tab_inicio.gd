extends Control
## res://scenes/tab_inicio.gd
## Figma 00 · Plantilla base / Sin módulo seleccionado (nodo 8:10375).
## Es el contenido de ContenedorCentral al entrar al juego, antes de elegir un módulo.

var _lbl_dias: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()
	Events.resources_updated.connect(_refresh)
	Events.sol_advanced.connect(_on_sol_advanced)


func _build() -> void:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", AresUI.box(AresUI.BG_PANEL, AresUI.BORDER))
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 27)
	margin.add_theme_constant_override("margin_right", 27)
	margin.add_theme_constant_override("margin_top", 23)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	# --- Cabecera ---
	col.add_child(AresUI.label("00 / CONSOLA EN ESPERA", 12, AresUI.TEAL))
	col.add_child(AresUI.label("SIN MÓDULO SELECCIONADO", 32, AresUI.TEXT, true))
	col.add_child(AresUI.hline())

	var gap_top := Control.new()
	gap_top.custom_minimum_size = Vector2(0, 52)
	gap_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap_top)

	# --- Bloque principal (sangría de 16 px, como en Figma) ---
	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 16)
	inner_margin.add_theme_constant_override("margin_right", 16)
	col.add_child(inner_margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	inner_margin.add_child(inner)

	var hero := AresUI.label("Tu rescate empieza en la Tierra.", 36, AresUI.TEXT, true)
	hero.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(hero)
	inner.add_child(AresUI.wrapped("Tú estás en Marte. Tu equipo está a un planeta de distancia.", 15, AresUI.MUTED))

	var food_row := HBoxContainer.new()
	food_row.add_theme_constant_override("separation", 0)
	inner.add_child(food_row)

	_lbl_dias = AresUI.label("60", 120, AresUI.AMBER, true)
	_lbl_dias.custom_minimum_size = Vector2(265, 0)
	food_row.add_child(_lbl_dias)

	var food_text := VBoxContainer.new()
	food_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_text.add_theme_constant_override("separation", 10)
	food_row.add_child(food_text)
	var food_gap := Control.new()
	food_gap.custom_minimum_size = Vector2(0, 22)
	food_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	food_text.add_child(food_gap)
	food_text.add_child(AresUI.label("DÍAS PARA EL RESCATE", 24, AresUI.AMBER, true))
	food_text.add_child(AresUI.wrapped(
		"Cada día cuenta. Planea, construye y consigue que el cohete llegue a Marte antes de que se acabe el plazo.",
		15, AresUI.MUTED))

	var gap_mid := Control.new()
	gap_mid.custom_minimum_size = Vector2(0, 28)
	gap_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(gap_mid)
	inner.add_child(AresUI.hline())

	var gap_sel := Control.new()
	gap_sel.custom_minimum_size = Vector2(0, 14)
	gap_sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(gap_sel)
	inner.add_child(AresUI.label("SELECCIONA UN MÓDULO A LA DERECHA  >>", 21, AresUI.TEAL, true))

	var gap_list := Control.new()
	gap_list.custom_minimum_size = Vector2(0, 10)
	gap_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(gap_list)

	_add_module(inner, "01 / MATERIALES", "Compra insumos. Su entrega tarda varios días.")
	_add_module(inner, "02 / MANTENIMIENTO", "Protege la base, la señal y los suministros.")
	_add_module(inner, "03 / DISEÑO", "Asigna trabajadores para fabricar cada pieza.")
	_add_module(inner, "04 / LANZAMIENTO", "Simula, corrige fallos y ejecuta el vuelo final.")

	var gap_end := Control.new()
	gap_end.custom_minimum_size = Vector2(0, 18)
	gap_end.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(gap_end)
	inner.add_child(AresUI.wrapped(
		"OBJETIVO / Coordina la Tierra. Consigue que el rescate llegue a tiempo.", 11, AresUI.MUTED))


func _add_module(parent: Control, titulo: String, desc: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var name_l := AresUI.label(titulo, 14, AresUI.TEXT, true)
	name_l.custom_minimum_size = Vector2(282, 0)
	row.add_child(name_l)
	var desc_l := AresUI.wrapped(desc, 12, AresUI.MUTED)
	row.add_child(desc_l)
	parent.add_child(row)
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 12)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sep)


func _on_sol_advanced(_sol: int) -> void:
	_refresh()


func _refresh() -> void:
	var dias: int = maxi(0, GameManager.MAX_SOLS - GameManager.current_sol)   # igual que la tarjeta PLAZO del header
	_lbl_dias.text = str(dias)
