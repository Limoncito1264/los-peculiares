extends Control
## Pestaña LANZAMIENTO (Figma 04) + modales 05 (simulación), 06 (confirmación) y 07 (victoria).
## Los modales se añaden a la escena raíz (CockpitMain) para cubrir toda la pantalla.

var _lbl_flight: Label
var _lbl_systems: Label
var _lbl_arrival: Label
var _btn_sim: Button
var _btn_launch: Button
var _lbl_msg: Label


func _ready() -> void:
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", AresUI.box(AresUI.BG_PANEL, AresUI.BORDER))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

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
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	col.add_child(AresUI.label("04 / PRUEBAS Y MISIÓN FINAL", 12, AresUI.AMBER))
	col.add_child(AresUI.label("Construye una oportunidad de volver.", 32, AresUI.TEXT, true))
	col.add_child(AresUI.label("Ganas si logras despegar antes de que se cierre la ventana de lanzamiento en el Sol %d." % GameManager.MAX_SOLS, 14, AresUI.MUTED))
	col.add_child(AresUI.hline())

	col.add_child(_build_route())

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 20)
	col.add_child(cards)
	cards.add_child(_build_sim_card())
	cards.add_child(_build_final_card())

	col.add_child(AresUI.label("CONTROL PREVIO AL DESPEGUE", 20, AresUI.TEXT, true))
	col.add_child(_build_systems_row())
	col.add_child(_build_arrival_row())
	col.add_child(AresUI.label("SI SUPERAS EL SOL %d, LA VENTANA DE DESPEGUE SE CIERRA." % GameManager.MAX_SOLS, 12, AresUI.AMBER))
	_lbl_msg = AresUI.label("", 12, AresUI.MUTED)
	col.add_child(_lbl_msg)

	Events.resources_updated.connect(_refresh)
	Events.part_state_changed.connect(_on_part_changed)
	_refresh()


# ------------------------------------------------------------------
# Construcción de UI
# ------------------------------------------------------------------
func _inset(margin: float = 17.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", AresUI.box(AresUI.BG_INSET, AresUI.BORDER, margin))
	return p


func _build_route() -> Control:
	var p := _inset()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)

	row.add_child(_route_col("CONSTRUCCIÓN / TIERRA", AresUI.TEAL, "COMPLEJO ATLAS", 27, AresUI.TEXT))
	_lbl_flight = AresUI.label("", 23, AresUI.AMBER, true)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(AresUI.label("VENTANA DE DESPEGUE", 10, AresUI.MUTED))
	mid.add_child(_lbl_flight)
	row.add_child(mid)
	row.add_child(_route_col("RESCATE / MARTE", AresUI.AMBER, "ASTRONAUTA", 27, AresUI.TEXT))

	v.add_child(AresUI.label("OBJETIVO: DESPEGAR EN %d SOLES O MENOS" % GameManager.MAX_SOLS, 10, AresUI.MUTED))
	return p


func _route_col(tag: String, tag_color: Color, big: String, big_size: int, big_color: Color) -> Control:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(AresUI.label(tag, 11, tag_color))
	c.add_child(AresUI.label(big, big_size, big_color, true))
	return c


func _card(bg: Color, border: Color, tag: String, tag_color: Color, title: String,
		desc: String, note: String, note_color: Color) -> Dictionary:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 272)
	p.add_theme_stylebox_override("panel", AresUI.box(bg, border, 17))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(AresUI.label(tag, 11, tag_color))
	v.add_child(AresUI.label(title, 28, AresUI.TEXT, true))
	var d := AresUI.wrapped(desc, 14, AresUI.MUTED)
	v.add_child(d)
	v.add_child(AresUI.spacer())
	v.add_child(AresUI.label(note, 11, note_color))
	return {"card": p, "body": v}


func _build_sim_card() -> Control:
	var c := _card(AresUI.BG_INSET, AresUI.BORDER, "01 / PRUEBA SIN RIESGO", AresUI.TEAL,
		"Simulación de vuelo",
		"Prueba la configuración actual. El informe identifica qué piezas faltan o qué sistema está fallando.",
		"No consume la nave ni materiales.", AresUI.TEAL)
	_btn_sim = AresUI.button("SIMULAR VUELO  >>", "teal", 44)
	_btn_sim.pressed.connect(_open_simulation)
	c["body"].add_child(_btn_sim)
	return c["card"]


func _build_final_card() -> Control:
	var c := _card(AresUI.LAUNCH_BG, AresUI.LAUNCH_BORDER, "02 / INTENTO DEFINITIVO", AresUI.AMBER,
		"Lanzamiento final",
		"Despega desde la Tierra hacia Marte. Esta vez la nave y sus recursos sí se ponen en riesgo.",
		"Solo disponible con %d / %d sistemas." % [GameManager.ROCKET_PARTS.size(), GameManager.ROCKET_PARTS.size()],
		AresUI.AMBER)
	_btn_launch = AresUI.button("REVISAR LANZAMIENTO  >>", "primary", 44)
	_btn_launch.pressed.connect(_open_confirm)
	c["body"].add_child(_btn_launch)
	return c["card"]


func _build_systems_row() -> Control:
	var p := _inset(15)
	p.custom_minimum_size = Vector2(0, 58)
	var h := HBoxContainer.new()
	p.add_child(h)
	var t := AresUI.label("SISTEMAS FABRICADOS", 13, AresUI.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	_lbl_systems = AresUI.label("0", 29, AresUI.AMBER, true)
	h.add_child(_lbl_systems)
	h.add_child(AresUI.label("  / %d" % GameManager.ROCKET_PARTS.size(), 13, AresUI.MUTED))
	return p


func _build_arrival_row() -> Control:
	var p := _inset(15)
	p.custom_minimum_size = Vector2(0, 62)
	var h := HBoxContainer.new()
	p.add_child(h)
	var t := AresUI.label("SOLES RESTANTES DE VENTANA DE DESPEGUE", 12, AresUI.MUTED)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	_lbl_arrival = AresUI.label("", 32, AresUI.TEXT, true)
	h.add_child(_lbl_arrival)
	return p


# ------------------------------------------------------------------
# Estado
# ------------------------------------------------------------------
func _on_part_changed(_i: int) -> void:
	_refresh()


func _refresh() -> void:
	if _lbl_systems == null:
		return
	var total := GameManager.ROCKET_PARTS.size()
	var listos := GameManager.systems_ready()
	_lbl_flight.text = "SOL %d MÁX  >>" % GameManager.MAX_SOLS
	_lbl_systems.text = str(listos)
	_lbl_arrival.text = "%d" % GameManager.launch_window_days_left()
	var sin_energia: bool = GameManager.tiene_falla("t_energia")
	var falla_soft: bool = GameManager.tiene_falla("t_software")
	if sin_energia:
		_btn_sim.disabled = true
		_btn_sim.text = "SIN ENERGÍA EN BASE"
		_btn_launch.disabled = true
		_lbl_msg.text = "Corte de energía en la Tierra: simulación y lanzamiento bloqueados."
	elif falla_soft:
		_btn_sim.disabled = true
		_btn_sim.text = "SERVIDOR FUERA DE LÍNEA"
		_btn_launch.disabled = listos < total
		_lbl_msg.text = "Falla de software: servidor de simulación reiniciándose."
	else:
		_btn_sim.disabled = false
		_btn_sim.text = "SIMULAR VUELO  >>"
		_btn_launch.disabled = listos < total
		_lbl_msg.text = "Faltan sistemas por fabricar. Revisa el modo simulación." if listos < total \
			else "Sistemas completos. Puedes revisar el lanzamiento."


# ------------------------------------------------------------------
# Modales
# ------------------------------------------------------------------
func _host() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else self


func _open_simulation() -> void:
	var s := LaunchSlingshot.open(_host(), true)
	s.preview_seconds = GameManager.get_launch_preview_seconds()

func _go_to_design(overlay: Node) -> void:
	overlay.queue_free()
	var host := _host()
	if host.has_method("cambiar_menu"):
		host.call_deferred("cambiar_menu", "diseno")


func _open_confirm() -> void:
	var listos := GameManager.systems_ready()
	var reason := GameManager.launch_block_reason()
	var puede := reason == ""

	var m := AresUI.modal(AresUI.AMBER, 536)
	var root: Control = m["root"]
	var body: VBoxContainer = m["body"]

	body.add_child(AresUI.label("MISIÓN FINAL / OPERACIÓN IRREVERSIBLE", 12, AresUI.AMBER))
	body.add_child(AresUI.label("¿Despegar hacia Marte?", 32, AresUI.TEXT, true))
	body.add_child(AresUI.wrapped(
		"La nave se arriesga en un lanzamiento real. Debes tener los cuatro sistemas fabricados y despegar en el Sol %d o antes." % GameManager.MAX_SOLS,
		15, AresUI.MUTED))
	body.add_child(AresUI.hline())

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 40)
	var s1 := VBoxContainer.new()
	s1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s1.add_child(AresUI.label("SISTEMAS LISTOS", 11, AresUI.MUTED))
	var s1row := HBoxContainer.new()
	s1row.add_child(AresUI.label(str(listos), 36, AresUI.AMBER, true))
	s1row.add_child(AresUI.label("  / %d" % GameManager.ROCKET_PARTS.size(), 14, AresUI.MUTED))
	s1.add_child(s1row)
	stats.add_child(s1)
	var s2 := VBoxContainer.new()
	s2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s2.add_child(AresUI.label("SOL DE DESPEGUE / LÍMITE", 11, AresUI.MUTED))
	s2.add_child(AresUI.label("%d / %d" % [GameManager.current_sol, GameManager.MAX_SOLS], 36, AresUI.TEXT, true))
	stats.add_child(s2)
	body.add_child(stats)

	if not puede:
		body.add_child(AresUI.wrapped(reason, 14, AresUI.AMBER))

	body.add_child(AresUI.spacer())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	var b_cancel := AresUI.button("CANCELAR", "secondary")
	b_cancel.custom_minimum_size = Vector2(240, 48)
	b_cancel.pressed.connect(root.queue_free)
	buttons.add_child(b_cancel)
	var b_go := AresUI.button("LANZAMIENTO FINAL  >>", "primary")
	b_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_go.disabled = not puede
	b_go.pressed.connect(_confirm_launch.bind(root))
	buttons.add_child(b_go)
	body.add_child(buttons)

	_host().add_child(root)


func _confirm_launch(overlay: Node) -> void:
	overlay.queue_free()
	var s := LaunchSlingshot.open(_host(), false)
	s.preview_seconds = GameManager.get_launch_preview_seconds()
	s.finished.connect(_on_slingshot_finished)


func _on_slingshot_finished(_success: bool) -> void:
	pass


func _open_victory(result: Dictionary) -> void:
	var m := AresUI.modal(AresUI.TEAL, 510)
	var root: Control = m["root"]
	var body: VBoxContainer = m["body"]

	body.add_child(AresUI.label("ENLACE DE RESCATE / MARTE", 12, AresUI.TEAL))
	body.add_child(AresUI.label("No estabas solo.", 48, AresUI.TEXT, true))
	body.add_child(AresUI.wrapped(
		"El cohete despegó dentro de la ventana orbital hacia Marte. El equipo de la Tierra lo consiguió contigo.",
		16, AresUI.MUTED))
	body.add_child(AresUI.hline())

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 40)
	var s1 := VBoxContainer.new()
	s1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s1.add_child(AresUI.label("SOL DE DESPEGUE", 11, AresUI.MUTED))
	s1.add_child(AresUI.label(str(result.get("launch_sol", GameManager.current_sol)), 38, AresUI.TEXT, true))
	stats.add_child(s1)
	var s2 := VBoxContainer.new()
	s2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s2.add_child(AresUI.label("SOLES DE MARGEN", 11, AresUI.MUTED))
	s2.add_child(AresUI.label(str(int(result.get("sols_left", 0))), 38, AresUI.TEAL, true))
	stats.add_child(s2)
	body.add_child(stats)

	body.add_child(AresUI.spacer())
	var b := AresUI.button("VOLVER A LA CONSOLA", "primary")
	b.pressed.connect(root.queue_free)
	body.add_child(b)
	

	_host().add_child(root)
