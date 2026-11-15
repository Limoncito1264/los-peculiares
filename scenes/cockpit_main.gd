extends Control
## res://scenes/cockpit_main.gd

@onready var contenedor_central: PanelContainer = $VBoxPrincipal/CuerpoMonitor/ContenedorCentral
@onready var ventana_notas: Panel = $VentanaNotas

@onready var lbl_sol_contador: Label = $VBoxPrincipal/HeaderSuperior/FilaArriba/CajaSolActual/LblSolContador
@onready var btn_siguiente_sol: Button = $VBoxPrincipal/HeaderSuperior/FilaArriba/CentroBotonSol/BtnSiguienteSol
@onready var lbl_dinero_valor: Label = $VBoxPrincipal/HeaderSuperior/FilaArriba/CajaDinero/LblDineroValor
@onready var btn_notas: Button = $VBoxPrincipal/HeaderSuperior/FilaArriba/BtnNotas

@onready var lbl_plazo_valor: Label = $VBoxPrincipal/HeaderSuperior/FilaTarjetas/CardPlazo/VBox/LblValor
@onready var lbl_trabajadores_valor: Label = $VBoxPrincipal/HeaderSuperior/FilaTarjetas/CardTrabajadores/VBox/LblValor
@onready var lbl_senal_valor: Label = $VBoxPrincipal/HeaderSuperior/FilaTarjetas/CardSenal/VBox/LblValor
@onready var lbl_electricidad_valor: Label = $VBoxPrincipal/HeaderSuperior/FilaTarjetas/CardElectricidad/VBox/LblValor

@onready var btn_comprar: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnComprar
@onready var btn_mantenimiento: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnMantenimiento
@onready var btn_diseno: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnDiseno
@onready var btn_lanzamiento: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnLanzamiento

const RUTAS_MENU := {
	"inicio": "res://scenes/tab_inicio.tscn",
	"comprar": "res://scenes/tab_materials.tscn",
	"mantenimiento": "res://scenes/tab_maintenance.tscn",
	"diseno": "res://scenes/tab_design.tscn",
	"lanzamiento": "res://scenes/tab_launch.tscn",
}
const TITULOS_MENU := {
	"inicio": "Inicio",
	"comprar": "Materiales",
	"mantenimiento": "Mantenimiento",
	"diseno": "Diseño",
	"lanzamiento": "Lanzamiento",
}

var _font_pixel: Font
var _font_mono: Font
var _refs_modulo := {}
var _estilo_mod_normal: StyleBoxFlat
var _estilo_mod_activo: StyleBoxFlat

var _tex_hangar: TextureRect
var _lbl_cam_estado: Label
var _lbl_hangar_titulo: Label
var _lbl_hangar_num: Label

var _tex_marte: TextureRect
var _lbl_marte_cam_estado: Label
var _lbl_marte_titulo: Label
var _lbl_marte_sub: Label
var _marte_anim_t: float = 0.0
var _marte_blink: bool = false


func _ready() -> void:
	_cargar_fuentes()
	_aplicar_estilo_ares()

	contenedor_central.size_flags_vertical = Control.SIZE_EXPAND_FILL

	btn_comprar.pressed.connect(cambiar_menu.bind("comprar"))
	btn_mantenimiento.pressed.connect(cambiar_menu.bind("mantenimiento"))
	btn_diseno.pressed.connect(cambiar_menu.bind("diseno"))
	btn_lanzamiento.pressed.connect(cambiar_menu.bind("lanzamiento"))

	btn_siguiente_sol.pressed.connect(_on_siguiente_sol_pressed)
	btn_notas.pressed.connect(func(): ventana_notas.visible = !ventana_notas.visible)
	ventana_notas.visible = false

	Events.resources_updated.connect(_actualizar_header)
	Events.signal_status_changed.connect(_actualizar_senal)
	Events.sol_advanced.connect(func(_s: int): _actualizar_header())
	if Events.has_signal("part_state_changed"):
		Events.part_state_changed.connect(func(_i: int):
			_actualizar_hangar()
			_actualizar_header()
		)
	GameManager.state_changed.connect(_actualizar_header)
	GameManager.state_changed.connect(_actualizar_hangar)

	GameManager.state_changed.connect(_actualizar_camara_marte)
	Events.signal_status_changed.connect(func(_a: bool): _actualizar_camara_marte())
	Events.sol_advanced.connect(func(_s: int): _actualizar_camara_marte())

	_actualizar_header()
	_actualizar_senal(GameManager.signal_active)
	_actualizar_hangar()
	_actualizar_camara_marte()
	cambiar_menu("inicio")


func _cargar_fuentes() -> void:
	if ResourceLoader.exists("res://themes/slkscr.ttf"):
		_font_pixel = load("res://themes/slkscr.ttf")
	if ResourceLoader.exists("res://themes/IBMPlexMono-Regular.ttf"):
		_font_mono = load("res://themes/IBMPlexMono-Regular.ttf")


func cambiar_menu(clave: String) -> void:
	for k in _refs_modulo:
		var ref: Dictionary = _refs_modulo[k]
		var activo: bool = (k == clave)
		var b: Button = ref["btn"]
		var ic: TextureRect = ref["icon"]
		var tit: Label = ref["tit"]
		var sub: Label = ref["sub"]

		b.add_theme_stylebox_override("normal", _estilo_mod_activo if activo else _estilo_mod_normal)
		ic.modulate = Color("#F2B84B") if activo else Color("#4CE0B3")
		tit.add_theme_color_override("font_color", Color("#F2B84B") if activo else Color("#F0F4F8"))
		sub.text = "EN PANTALLA" if activo else "ABRIR MÓDULO"
		sub.add_theme_color_override("font_color", Color("#C9963B") if activo else Color("#6B7F99"))

	for hijo in contenedor_central.get_children():
		contenedor_central.remove_child(hijo)
		hijo.queue_free()

	var ruta: String = RUTAS_MENU[clave]
	var nueva: Control
	if ResourceLoader.exists(ruta):
		nueva = (load(ruta) as PackedScene).instantiate()
	else:
		nueva = _crear_placeholder(clave)

	_estilizar_contenido_tab(nueva)
	contenedor_central.add_child(nueva)


func _estilizar_contenido_tab(nodo: Node) -> void:
	if nodo is Label:
		var lbl := nodo as Label
		var txt := lbl.text.strip_edges()
		var tam := lbl.get_theme_font_size("font_size")
		var es_titulo_pixel := (
			tam >= 18
			or txt.begins_with("SIN MÓDULO")
			or txt.begins_with("Tu rescate")
			or txt.begins_with("SELECCIONA")
			or txt.begins_with("DÍAS PARA")
			or txt.begins_with("01 / MATERIALES")
			or txt.begins_with("02 / MANTENIMIENTO")
			or txt.begins_with("03 / DISEÑO")
			or txt.begins_with("04 / LANZAMIENTO")
		)
		if _font_pixel and es_titulo_pixel:
			lbl.add_theme_font_override("font", _font_pixel)
			if txt.begins_with("SIN MÓDULO") or txt.begins_with("Tu rescate"):
				lbl.add_theme_font_size_override("font_size", 26)
			elif txt.begins_with("DÍAS PARA") or txt.begins_with("SELECCIONA"):
				lbl.add_theme_font_size_override("font_size", 20)
			elif txt.is_valid_int():
				lbl.add_theme_font_size_override("font_size", 68)
			elif txt.begins_with("0"):
				lbl.add_theme_font_size_override("font_size", 15)
		elif _font_mono:
			lbl.add_theme_font_override("font", _font_mono)
			if tam < 14:
				lbl.add_theme_font_size_override("font_size", 14)
	elif nodo is Button and _font_pixel:
		(nodo as Button).add_theme_font_override("font", _font_pixel)
	elif nodo is HSeparator:
		var sep := StyleBoxLine.new()
		sep.color = Color("#1E2D42")
		sep.thickness = 1
		(nodo as HSeparator).add_theme_stylebox_override("separator", sep)

	for hijo in nodo.get_children():
		_estilizar_contenido_tab(hijo)


func _crear_placeholder(clave: String) -> Control:
	var lbl := Label.new()
	lbl.text = "%s\n(en construcción)" % TITULOS_MENU[clave]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _font_pixel:
		lbl.add_theme_font_override("font", _font_pixel)
		lbl.add_theme_font_size_override("font_size", 22)
	return lbl


func _on_siguiente_sol_pressed() -> void:
	GameManager.advance_sol()
	_actualizar_header()


func _actualizar_header() -> void:
	var sol_actual: int = GameManager.current_sol
	var soles_restantes: int = max(0, 60 - sol_actual)

	lbl_sol_contador.text = "SOL %d / 60" % sol_actual
	lbl_plazo_valor.text = "%d / 60 SOLES" % soles_restantes
	lbl_trabajadores_valor.text = "%d / %d LIBRES" % [GameManager.workers_free(), GameManager.staff_count]
	lbl_dinero_valor.text = "%d USD" % GameManager.budget
	for h in $VBoxPrincipal/HeaderSuperior/FilaArriba/CentroBotonSol.get_children():
		if h is Label:
			(h as Label).visible = false

	var baja_energia: bool = GameManager.tiene_falla("mars_solar_dust")
	lbl_electricidad_valor.text = "35% · AHORRO" if baja_energia else "88% · OPERATIVA"
	lbl_electricidad_valor.modulate = Color("#F2B84B") if baja_energia else Color("#4CE0B3")
	btn_notas.disabled = baja_energia
	if baja_energia:
		ventana_notas.visible = false

	if _lbl_cam_estado:
		if baja_energia:
			_lbl_cam_estado.text = "CAM 01 / MODO AHORRO"
			_lbl_cam_estado.add_theme_color_override("font_color", Color("#F2B84B"))
		else:
			_lbl_cam_estado.text = "CAM 01 / EN LÍNEA"
			_lbl_cam_estado.add_theme_color_override("font_color", Color("#4CE0B3"))


func _actualizar_senal(esta_en_linea: bool) -> void:
	if esta_en_linea:
		lbl_senal_valor.text = "100% · ESTABLE"
		lbl_senal_valor.modulate = Color("#4CE0B3")
	else:
		lbl_senal_valor.text = "0% · SIN SEÑAL"
		lbl_senal_valor.modulate = Color("#FF5C5C")


func _aplicar_estilo_ares() -> void:
	if not has_node("FondoEspacio"):
		var fondo := ColorRect.new()
		fondo.name = "FondoEspacio"
		fondo.color = Color("#090E16")
		fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fondo)
		move_child(fondo, 0)

	var vbox_principal: VBoxContainer = $VBoxPrincipal
	if ResourceLoader.exists("res://themes/ares_theme.tres"):
		vbox_principal.theme = load("res://themes/ares_theme.tres")
	if _font_mono and vbox_principal.theme:
		vbox_principal.theme.default_font = _font_mono

	vbox_principal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox_principal.offset_left = 18
	vbox_principal.offset_right = -18
	vbox_principal.offset_top = 12
	vbox_principal.offset_bottom = -10
	vbox_principal.add_theme_constant_override("separation", 10)

	var header: VBoxContainer = $VBoxPrincipal/HeaderSuperior
	header.add_theme_constant_override("separation", 10)

	var fila_arriba: HBoxContainer = $VBoxPrincipal/HeaderSuperior/FilaArriba
	fila_arriba.add_theme_constant_override("separation", 16)

	var caja_sol: Control = $VBoxPrincipal/HeaderSuperior/FilaArriba/CajaSolActual
	_estilizar_labels_header_izq(caja_sol)
	if _font_pixel:
		lbl_sol_contador.add_theme_font_override("font", _font_pixel)
	lbl_sol_contador.add_theme_font_size_override("font_size", 20)
	lbl_sol_contador.add_theme_color_override("font_color", Color("#F0F4F8"))

	var centro_sol: Control = $VBoxPrincipal/HeaderSuperior/FilaArriba/CentroBotonSol
	centro_sol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_siguiente_sol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_siguiente_sol.custom_minimum_size = Vector2(320, 46)
	btn_siguiente_sol.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var estilo_btn := StyleBoxFlat.new()
	estilo_btn.bg_color = Color("#F2B84B")
	estilo_btn.set_corner_radius_all(2)
	estilo_btn.content_margin_left = 24
	estilo_btn.content_margin_right = 24
	estilo_btn.content_margin_top = 10
	estilo_btn.content_margin_bottom = 10

	var estilo_btn_hover := estilo_btn.duplicate()
	estilo_btn_hover.bg_color = Color("#FFD06B")

	btn_siguiente_sol.add_theme_stylebox_override("normal", estilo_btn)
	btn_siguiente_sol.add_theme_stylebox_override("hover", estilo_btn_hover)
	btn_siguiente_sol.add_theme_stylebox_override("pressed", estilo_btn)
	btn_siguiente_sol.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_siguiente_sol.add_theme_color_override("font_color", Color("#0B111A"))
	btn_siguiente_sol.add_theme_color_override("font_hover_color", Color("#0B111A"))
	btn_siguiente_sol.add_theme_color_override("font_pressed_color", Color("#0B111A"))
	btn_siguiente_sol.add_theme_font_size_override("font_size", 15)
	if _font_pixel:
		btn_siguiente_sol.add_theme_font_override("font", _font_pixel)

	for h in centro_sol.get_children():
		if h is Label:
			(h as Label).visible = false

	var caja_dinero: Control = $VBoxPrincipal/HeaderSuperior/FilaArriba/CajaDinero
	for h in caja_dinero.get_children():
		if h is Label and h != lbl_dinero_valor:
			(h as Label).add_theme_font_size_override("font_size", 12)
			(h as Label).add_theme_color_override("font_color", Color("#6B7F99"))

	if _font_pixel:
		lbl_dinero_valor.add_theme_font_override("font", _font_pixel)
	lbl_dinero_valor.add_theme_font_size_override("font_size", 28)
	lbl_dinero_valor.modulate = Color("#F2B84B")

	var estilo_notas := StyleBoxFlat.new()
	estilo_notas.bg_color = Color("#0E1520")
	estilo_notas.border_color = Color("#1E2D42")
	estilo_notas.set_border_width_all(1)
	estilo_notas.set_corner_radius_all(2)
	estilo_notas.content_margin_left = 16
	estilo_notas.content_margin_right = 16
	estilo_notas.content_margin_top = 8
	estilo_notas.content_margin_bottom = 8
	btn_notas.custom_minimum_size = Vector2(90, 40)
	btn_notas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_notas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_notas.add_theme_stylebox_override("normal", estilo_notas)
	btn_notas.add_theme_color_override("font_color", Color("#E8EEF5"))
	btn_notas.add_theme_font_size_override("font_size", 13)
	if _font_pixel:
		btn_notas.add_theme_font_override("font", _font_pixel)

	var fila_tarjetas: HBoxContainer = $VBoxPrincipal/HeaderSuperior/FilaTarjetas
	fila_tarjetas.add_theme_constant_override("separation", 10)

	var estilo_card := StyleBoxFlat.new()
	estilo_card.bg_color = Color("#0E1520")
	estilo_card.border_color = Color("#1E2D42")
	estilo_card.set_border_width_all(1)
	estilo_card.set_corner_radius_all(2)
	estilo_card.content_margin_left = 14
	estilo_card.content_margin_right = 14
	estilo_card.content_margin_top = 10
	estilo_card.content_margin_bottom = 10

	for card in fila_tarjetas.get_children():
		if card is PanelContainer:
			card.add_theme_stylebox_override("panel", estilo_card)
			_estilizar_card_header(card)

	var cuerpo: HBoxContainer = $VBoxPrincipal/CuerpoMonitor
	cuerpo.add_theme_constant_override("separation", 14)

	if cuerpo.get_child_count() >= 3:
		var panel_izq := cuerpo.get_child(0) as Control
		var panel_der := $VBoxPrincipal/CuerpoMonitor/PanelDerecho as Control

		panel_izq.custom_minimum_size.x = 250
		panel_izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel_izq.size_flags_stretch_ratio = 0.72

		contenedor_central.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		contenedor_central.size_flags_stretch_ratio = 2.35

		panel_der.custom_minimum_size.x = 320
		panel_der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel_der.size_flags_stretch_ratio = 0.90

		_estilizar_panel_izquierdo(panel_izq)

	var estilo_centro := StyleBoxFlat.new()
	estilo_centro.bg_color = Color("#0E1520")
	estilo_centro.border_color = Color("#1E2D42")
	estilo_centro.set_border_width_all(1)
	estilo_centro.set_corner_radius_all(2)
	estilo_centro.content_margin_left = 26
	estilo_centro.content_margin_right = 26
	estilo_centro.content_margin_top = 20
	estilo_centro.content_margin_bottom = 20
	contenedor_central.add_theme_stylebox_override("panel", estilo_centro)

	_estilizar_modulos_derecha()
	_construir_camara_hangar()
	_construir_camara_marte()
	_construir_footer()


func _estilizar_panel_izquierdo(nodo: Node, en_tarjeta_evento: bool = false) -> void:
	var es_subtarjeta := false
	if nodo is PanelContainer:
		var tiene_titulo_seccion := false
		for c in nodo.find_children("*", "Label", true, false):
			var t := (c as Label).text.strip_edges()
			if t.begins_with("PRÓXIMOS") or t.begins_with("PLAN DE"):
				tiene_titulo_seccion = true
				break
		es_subtarjeta = not tiene_titulo_seccion
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#0E1520")
		st.border_color = Color("#1E2D42")
		st.set_border_width_all(1)
		st.set_corner_radius_all(2)
		st.content_margin_left = 14 if es_subtarjeta else 12
		st.content_margin_right = 14 if es_subtarjeta else 12
		st.content_margin_top = 13 if es_subtarjeta else 10
		st.content_margin_bottom = 13 if es_subtarjeta else 10
		(nodo as PanelContainer).add_theme_stylebox_override("panel", st)
	elif nodo is Label:
		var l := nodo as Label
		var txt := l.text.strip_edges()
		if en_tarjeta_evento:
			if txt == "DÍA":
				if _font_mono:
					l.add_theme_font_override("font", _font_mono)
				l.add_theme_font_size_override("font_size", 12)
			elif txt == "-" or (txt.is_valid_int() and txt.length() <= 2):
				if _font_pixel:
					l.add_theme_font_override("font", _font_pixel)
				l.add_theme_font_size_override("font_size", 15)
			else:
				if _font_pixel:
					l.add_theme_font_override("font", _font_pixel)
				l.add_theme_font_size_override("font_size", 16)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif _font_pixel and (txt.begins_with("PRÓXIMOS") or txt.begins_with("PLAN DE")):
			l.add_theme_font_override("font", _font_pixel)
			l.add_theme_font_size_override("font_size", 20)
		elif _font_pixel and txt.begins_with("LÍMITE"):
			l.add_theme_font_override("font", _font_pixel)
			l.add_theme_font_size_override("font_size", 16)
		elif _font_pixel and txt.is_valid_int() and int(txt) >= 1 and txt.length() <= 2 and not txt.begins_with("0"):
			l.add_theme_font_override("font", _font_pixel)
			l.add_theme_font_size_override("font_size", 22)
		elif _font_mono:
			l.add_theme_font_override("font", _font_mono)
			if txt.begins_with("DÍA ACTUAL") or txt.begins_with("DÍA "):
				l.add_theme_font_size_override("font_size", 13)
			elif txt.begins_with("Cada pedido"):
				l.add_theme_font_size_override("font_size", 13)
			else:
				l.add_theme_font_size_override("font_size", 12)
	for h in nodo.get_children():
		_estilizar_panel_izquierdo(h, en_tarjeta_evento or es_subtarjeta)


func _estilizar_labels_header_izq(nodo: Node) -> void:
	for h in nodo.get_children():
		if h is Label and h != lbl_sol_contador:
			var l := h as Label
			if "ODYSSEY-60" in l.text:
				if _font_pixel:
					l.add_theme_font_override("font", _font_pixel)
				l.add_theme_font_size_override("font_size", 28)
				l.add_theme_color_override("font_color", Color("#F0F4F8"))
			elif "COORDINACION" in l.text or "COORDINACIÓN" in l.text:
				l.add_theme_font_size_override("font_size", 12)
				l.add_theme_color_override("font_color", Color("#4CE0B3"))
			else:
				l.add_theme_font_size_override("font_size", 12)
				l.add_theme_color_override("font_color", Color("#6B7F99"))
		_estilizar_labels_header_izq(h)


func _estilizar_card_header(nodo: Node) -> void:
	for h in nodo.get_children():
		if h is Label:
			var l := h as Label
			if l.name == "LblValor":
				if _font_pixel:
					l.add_theme_font_override("font", _font_pixel)
				l.add_theme_font_size_override("font_size", 18)
			else:
				l.add_theme_font_size_override("font_size", 12)
				l.add_theme_color_override("font_color", Color("#6B7F99"))
		_estilizar_card_header(h)


func _estilizar_modulos_derecha() -> void:
	var panel_der: VBoxContainer = $VBoxPrincipal/CuerpoMonitor/PanelDerecho
	var grid: GridContainer = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu

	for hijo in panel_der.get_children():
		if hijo != grid and hijo.name != "LblModulosMision" and hijo.name != "CardCamaraHangar":
			hijo.visible = false

	panel_der.add_theme_constant_override("separation", 10)

	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_stretch_ratio = 0.74
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)

	if not panel_der.has_node("LblModulosMision"):
		var lbl_sec := Label.new()
		lbl_sec.name = "LblModulosMision"
		lbl_sec.text = "MÓDULOS DE MISIÓN"
		lbl_sec.add_theme_font_size_override("font_size", 13)
		lbl_sec.add_theme_color_override("font_color", Color("#6B7F99"))
		panel_der.add_child(lbl_sec)
		panel_der.move_child(lbl_sec, 0)

	_estilo_mod_normal = StyleBoxFlat.new()
	_estilo_mod_normal.bg_color = Color("#0E1520")
	_estilo_mod_normal.border_color = Color("#1E2D42")
	_estilo_mod_normal.set_border_width_all(1)
	_estilo_mod_normal.set_corner_radius_all(2)

	var estilo_hover := StyleBoxFlat.new()
	estilo_hover.bg_color = Color("#142030")
	estilo_hover.border_color = Color("#4CE0B3")
	estilo_hover.set_border_width_all(1)
	estilo_hover.set_corner_radius_all(2)

	_estilo_mod_activo = StyleBoxFlat.new()
	_estilo_mod_activo.bg_color = Color("#1D1912")
	_estilo_mod_activo.border_color = Color("#F2B84B")
	_estilo_mod_activo.set_border_width_all(1)
	_estilo_mod_activo.set_corner_radius_all(2)

	var botones := {
		"comprar": btn_comprar,
		"mantenimiento": btn_mantenimiento,
		"diseno": btn_diseno,
		"lanzamiento": btn_lanzamiento,
	}

	var config := [
		["comprar", "01", "Materiales"],
		["mantenimiento", "02", "Mantenimiento"],
		["diseno", "03", "Diseño"],
		["lanzamiento", "04", "Lanzamiento"],
	]

	_refs_modulo.clear()

	for item in config:
		var clave: String = item[0]
		var num: String = item[1]
		var titulo: String = item[2]
		var btn: Button = botones[clave]

		btn.text = ""
		btn.custom_minimum_size = Vector2(0, 124)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_stylebox_override("normal", _estilo_mod_normal)
		btn.add_theme_stylebox_override("hover", estilo_hover)
		btn.add_theme_stylebox_override("pressed", _estilo_mod_activo)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		for c in btn.get_children():
			c.queue_free()

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_bottom", 14)
		btn.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 5)
		margin.add_child(vbox)

		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(hbox)

		var tex_rect := TextureRect.new()
		tex_rect.texture = _crear_icono_modulo(clave)
		tex_rect.modulate = Color("#4CE0B3")
		tex_rect.custom_minimum_size = Vector2(32, 32)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(tex_rect)

		var lbl_num := Label.new()
		lbl_num.text = num
		lbl_num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_num.add_theme_font_size_override("font_size", 14)
		lbl_num.add_theme_color_override("font_color", Color("#6B7F99"))
		lbl_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl_num)

		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(spacer)

		var lbl_tit := Label.new()
		lbl_tit.text = titulo
		if _font_pixel:
			lbl_tit.add_theme_font_override("font", _font_pixel)
		lbl_tit.add_theme_font_size_override("font_size", 21)
		lbl_tit.add_theme_color_override("font_color", Color("#F0F4F8"))
		lbl_tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl_tit)

		var lbl_sub := Label.new()
		lbl_sub.text = "ABRIR MÓDULO"
		lbl_sub.add_theme_font_size_override("font_size", 12)
		lbl_sub.add_theme_color_override("font_color", Color("#6B7F99"))
		lbl_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl_sub)

		_refs_modulo[clave] = {
			"btn": btn,
			"icon": tex_rect,
			"tit": lbl_tit,
			"sub": lbl_sub,
		}


func _construir_camara_hangar() -> void:
	var panel_der: VBoxContainer = $VBoxPrincipal/CuerpoMonitor/PanelDerecho
	if panel_der.has_node("CardCamaraHangar"):
		return

	var card := PanelContainer.new()
	card.name = "CardCamaraHangar"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#0E1520")
	st.border_color = Color("#1E2D42")
	st.set_border_width_all(1)
	st.set_corner_radius_all(2)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 16
	st.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", st)
	panel_der.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var tit := Label.new()
	tit.text = "CÁMARA DEL HANGAR"
	if _font_pixel:
		tit.add_theme_font_override("font", _font_pixel)
	tit.add_theme_font_size_override("font_size", 21)
	tit.add_theme_color_override("font_color", Color("#F0F4F8"))
	vbox.add_child(tit)

	var sub := Label.new()
	sub.text = "TIERRA / COMPLEJO ATLAS"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color("#6B7F99"))
	vbox.add_child(sub)

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var st_cam := StyleBoxFlat.new()
	st_cam.bg_color = Color("#090E16")
	st_cam.border_color = Color("#1E2D42")
	st_cam.set_border_width_all(1)
	st_cam.content_margin_left = 10
	st_cam.content_margin_right = 10
	st_cam.content_margin_top = 8
	st_cam.content_margin_bottom = 8
	frame.add_theme_stylebox_override("panel", st_cam)
	vbox.add_child(frame)

	var cam_box := VBoxContainer.new()
	cam_box.add_theme_constant_override("separation", 4)
	frame.add_child(cam_box)

	_lbl_cam_estado = Label.new()
	_lbl_cam_estado.text = "CAM 01 / EN LÍNEA"
	_lbl_cam_estado.add_theme_font_size_override("font_size", 11)
	_lbl_cam_estado.add_theme_color_override("font_color", Color("#4CE0B3"))
	cam_box.add_child(_lbl_cam_estado)

	_tex_hangar = TextureRect.new()
	_tex_hangar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tex_hangar.custom_minimum_size = Vector2(0, 150)
	_tex_hangar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_hangar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_hangar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cam_box.add_child(_tex_hangar)

	_lbl_hangar_titulo = Label.new()
	_lbl_hangar_titulo.text = "Sin piezas ensambladas"
	if _font_pixel:
		_lbl_hangar_titulo.add_theme_font_override("font", _font_pixel)
	_lbl_hangar_titulo.add_theme_font_size_override("font_size", 18)
	_lbl_hangar_titulo.add_theme_color_override("font_color", Color("#F0F4F8"))
	vbox.add_child(_lbl_hangar_titulo)

	var lbl_prog := Label.new()
	lbl_prog.text = "PROGRESO DE ENSAMBLAJE"
	lbl_prog.add_theme_font_size_override("font_size", 11)
	lbl_prog.add_theme_color_override("font_color", Color("#6B7F99"))
	vbox.add_child(lbl_prog)

	var h_prog := HBoxContainer.new()
	h_prog.add_theme_constant_override("separation", 12)
	vbox.add_child(h_prog)

	_lbl_hangar_num = Label.new()
	_lbl_hangar_num.text = "0"
	if _font_pixel:
		_lbl_hangar_num.add_theme_font_override("font", _font_pixel)
	_lbl_hangar_num.add_theme_font_size_override("font_size", 30)
	_lbl_hangar_num.add_theme_color_override("font_color", Color("#F2B84B"))
	h_prog.add_child(_lbl_hangar_num)

	var lbl_tot := Label.new()
	lbl_tot.text = "/ 4 SISTEMAS"
	lbl_tot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_tot.add_theme_font_size_override("font_size", 13)
	lbl_tot.add_theme_color_override("font_color", Color("#7C8FA6"))
	h_prog.add_child(lbl_tot)

	var sep := HSeparator.new()
	var st_sep := StyleBoxLine.new()
	st_sep.color = Color("#1E2D42")
	sep.add_theme_stylebox_override("separator", st_sep)
	vbox.add_child(sep)

	var nota := Label.new()
	nota.text = "El hangar cambia al terminar piezas."
	nota.add_theme_font_size_override("font_size", 12)
	nota.add_theme_color_override("font_color", Color("#6B7F99"))
	vbox.add_child(nota)


func _construir_footer() -> void:
	var vbox_principal: VBoxContainer = $VBoxPrincipal
	if vbox_principal.has_node("FooterAres"):
		return

	var footer := HBoxContainer.new()
	footer.name = "FooterAres"
	vbox_principal.add_child(footer)

	var izq := Label.new()
	izq.text = "ODYSSEY-60 / RESCATE REMOTO   ·   ASTRONAUTA EN MARTE"
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izq.add_theme_font_size_override("font_size", 12)
	izq.add_theme_color_override("font_color", Color("#6B7F99"))
	footer.add_child(izq)



func _actualizar_hangar() -> void:
	if not _tex_hangar:
		return
	var listos: int = GameManager.systems_ready()
	_lbl_hangar_num.text = str(listos)
	if listos == 0:
		_lbl_hangar_titulo.text = "Sin piezas ensambladas"
	elif listos < 4:
		_lbl_hangar_titulo.text = "%d de 4 sistemas listos" % listos
	else:
		_lbl_hangar_titulo.text = "Cohete listo para lanzar"

	_tex_hangar.texture = _dibujar_hangar_pixel()


func _dibujar_hangar_pixel() -> ImageTexture:
	var W := 96
	var H := 64
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)

	var sky := Color("#0B131E")
	var skyline := Color("#121D2D")
	var wall := Color("#2B3D4F")
	var wall_dark := Color("#1C2938")
	var bay := Color("#090F18")
	var floor_col := Color("#33485E")
	var teal := Color("#4CE0B3")
	var amber := Color("#F2B84B")
	var dark_stripe := Color("#101824")
	var rocket_body := Color("#D8E2EC")
	var rocket_shade := Color("#8FA3B8")

	img.fill(sky)

	var estrellas := [
		[6, 5], [14, 12], [22, 4], [74, 6], [86, 11], [90, 4],
		[10, 22], [82, 20], [18, 16], [68, 14], [4, 14], [92, 18]
	]
	for p in estrellas:
		img.set_pixel(p[0], p[1], Color("#526880"))

	_fill_rect(img, 0, 34, 24, 22, skyline)
	_fill_rect(img, 6, 30, 10, 4, skyline)
	_fill_rect(img, 72, 32, 24, 24, skyline)
	_fill_rect(img, 78, 28, 12, 4, skyline)

	_fill_rect(img, 74, 8, 2, 10, wall)
	_fill_rect(img, 70, 9, 10, 2, teal)
	_fill_rect(img, 72, 7, 6, 1, wall)

	_fill_rect(img, 24, 16, 48, 40, wall)
	_fill_rect(img, 28, 13, 40, 3, wall)
	_fill_rect(img, 32, 11, 32, 2, wall_dark)
	_fill_rect(img, 25, 16, 1, 40, teal)
	_fill_rect(img, 70, 16, 1, 40, teal)
	_fill_rect(img, 28, 13, 40, 1, teal)
	_fill_rect(img, 28, 21, 5, 2, teal)
	_fill_rect(img, 63, 21, 5, 2, teal)

	_fill_rect(img, 36, 18, 24, 38, bay)
	_fill_rect(img, 35, 18, 1, 38, teal)
	_fill_rect(img, 60, 18, 1, 38, teal)

	for y in range(22, 50, 4):
		_fill_rect(img, 36, y, 4, 1, Color("#3E5870"))
		_fill_rect(img, 56, y, 4, 1, Color("#3E5870"))

	for y in range(46, 56):
		var col_p := amber if ((y / 2) % 2 == 0) else dark_stripe
		_fill_rect(img, 34, y, 2, 1, col_p)
		_fill_rect(img, 60, y, 2, 1, col_p)

	_fill_rect(img, 8, 36, 16, 20, wall)
	_fill_rect(img, 10, 34, 12, 2, wall_dark)
	_fill_rect(img, 11, 39, 10, 2, teal)
	_fill_rect(img, 11, 45, 10, 11, wall_dark)
	for y in range(47, 55, 2):
		_fill_rect(img, 12, y, 8, 1, Color("#263849"))

	_fill_rect(img, 72, 36, 16, 20, wall)
	_fill_rect(img, 74, 34, 12, 2, wall_dark)
	_fill_rect(img, 75, 39, 10, 2, teal)
	_fill_rect(img, 80, 46, 5, 10, wall_dark)

	var estados: Array = GameManager.part_state
	if estados.size() > 0 and estados[0] == GameManager.PartState.READY:
		_fill_rect(img, 45, 27, 6, 16, rocket_body)
		_fill_rect(img, 49, 27, 2, 16, rocket_shade)
		_fill_rect(img, 47, 31, 2, 3, teal)
	if estados.size() > 1 and estados[1] == GameManager.PartState.READY:
		_fill_rect(img, 44, 49, 8, 4, wall_dark)
		_fill_rect(img, 42, 46, 2, 6, amber)
		_fill_rect(img, 52, 46, 2, 6, amber)
	if estados.size() > 2 and estados[2] == GameManager.PartState.READY:
		_fill_rect(img, 44, 43, 8, 6, rocket_shade)
		_fill_rect(img, 45, 44, 6, 4, amber)
	if estados.size() > 3 and estados[3] == GameManager.PartState.READY:
		_fill_rect(img, 46, 24, 4, 3, rocket_body)
		_fill_rect(img, 47, 21, 2, 3, amber)

	_fill_rect(img, 0, 56, W, 8, floor_col)
	_fill_rect(img, 0, 56, W, 1, Color("#4D6882"))
	_fill_rect(img, 41, 58, 3, 1, amber)
	_fill_rect(img, 41, 58, 1, 3, amber)
	_fill_rect(img, 41, 60, 3, 1, amber)
	_fill_rect(img, 52, 58, 3, 1, amber)
	_fill_rect(img, 54, 58, 1, 3, amber)
	_fill_rect(img, 52, 60, 3, 1, amber)

	return ImageTexture.create_from_image(img)


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for py in range(maxi(0, y), mini(img.get_height(), y + h)):
		for px in range(maxi(0, x), mini(img.get_width(), x + w)):
			img.set_pixel(px, py, col)


func _crear_icono_modulo(clave: String) -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color.WHITE

	match clave:
		"comprar":
			_dibujar_linea_gruesa(img, 12, 3, 20, 7, c)
			_dibujar_linea_gruesa(img, 20, 7, 12, 11, c)
			_dibujar_linea_gruesa(img, 12, 11, 4, 7, c)
			_dibujar_linea_gruesa(img, 4, 7, 12, 3, c)
			_dibujar_linea_gruesa(img, 4, 7, 4, 16, c)
			_dibujar_linea_gruesa(img, 12, 11, 12, 20, c)
			_dibujar_linea_gruesa(img, 20, 7, 20, 16, c)
			_dibujar_linea_gruesa(img, 4, 16, 12, 20, c)
			_dibujar_linea_gruesa(img, 12, 20, 20, 16, c)
		"mantenimiento":
			_dibujar_linea_gruesa(img, 5, 18, 15, 8, c)
			_dibujar_linea_gruesa(img, 14, 4, 18, 4, c)
			_dibujar_linea_gruesa(img, 14, 4, 14, 7, c)
			_dibujar_linea_gruesa(img, 19, 6, 19, 10, c)
			_dibujar_linea_gruesa(img, 16, 10, 19, 10, c)
			_dibujar_linea_gruesa(img, 4, 17, 6, 19, c)
		"diseno":
			_dibujar_linea_gruesa(img, 6, 6, 17, 6, c)
			_dibujar_linea_gruesa(img, 17, 6, 17, 17, c)
			_dibujar_linea_gruesa(img, 17, 17, 6, 17, c)
			_dibujar_linea_gruesa(img, 6, 17, 6, 6, c)
			_dibujar_linea_gruesa(img, 9, 9, 14, 9, c)
			_dibujar_linea_gruesa(img, 14, 9, 14, 14, c)
			_dibujar_linea_gruesa(img, 14, 14, 9, 14, c)
			_dibujar_linea_gruesa(img, 9, 14, 9, 9, c)
			_dibujar_linea_gruesa(img, 10, 3, 13, 3, c)
			_dibujar_linea_gruesa(img, 10, 20, 13, 20, c)
			_dibujar_linea_gruesa(img, 3, 10, 3, 13, c)
			_dibujar_linea_gruesa(img, 20, 10, 20, 13, c)
		"lanzamiento":
			_dibujar_linea_gruesa(img, 19, 4, 15, 4, c)
			_dibujar_linea_gruesa(img, 19, 4, 19, 8, c)
			_dibujar_linea_gruesa(img, 15, 4, 9, 10, c)
			_dibujar_linea_gruesa(img, 19, 8, 13, 14, c)
			_dibujar_linea_gruesa(img, 9, 10, 9, 14, c)
			_dibujar_linea_gruesa(img, 9, 14, 13, 14, c)
			_dibujar_linea_gruesa(img, 9, 10, 5, 11, c)
			_dibujar_linea_gruesa(img, 5, 11, 7, 14, c)
			_dibujar_linea_gruesa(img, 13, 14, 12, 18, c)
			_dibujar_linea_gruesa(img, 12, 18, 9, 16, c)
			_dibujar_linea_gruesa(img, 4, 18, 6, 16, c)

	return ImageTexture.create_from_image(img)


func _dibujar_linea_gruesa(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		for oy in range(2):
			for ox in range(2):
				var px := x + ox
				var py := y + oy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, col)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


func _process(delta: float) -> void:
	if _tex_marte == null:
		return
	_marte_anim_t += delta
	if _marte_anim_t >= 0.75:
		_marte_anim_t = 0.0
		_marte_blink = not _marte_blink
		_tex_marte.texture = _dibujar_marte_pixel()


func _construir_camara_marte() -> void:
	var panel_izq: VBoxContainer = $VBoxPrincipal/CuerpoMonitor/PanelIzquierdo
	if panel_izq.has_node("CardCamaraMarte"):
		return

	var card := PanelContainer.new()
	card.name = "CardCamaraMarte"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#0E1520")
	st.border_color = Color("#1E2D42")
	st.set_border_width_all(1)
	st.set_corner_radius_all(2)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", st)
	panel_izq.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 1)
	vbox.add_child(header)

	var tit := Label.new()
	tit.text = "CÁMARA DE MARTE"
	if _font_pixel:
		tit.add_theme_font_override("font", _font_pixel)
	tit.add_theme_font_size_override("font_size", 16)
	tit.add_theme_color_override("font_color", Color("#F0F4F8"))
	header.add_child(tit)

	var sub := Label.new()
	sub.text = "MARTE / BASE ODYSSEY"
	if _font_mono:
		sub.add_theme_font_override("font", _font_mono)
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color("#6B7F99"))
	header.add_child(sub)

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var st_cam := StyleBoxFlat.new()
	st_cam.bg_color = Color("#060911")
	st_cam.border_color = Color("#1E2D42")
	st_cam.set_border_width_all(1)
	st_cam.set_corner_radius_all(2)
	st_cam.content_margin_left = 8
	st_cam.content_margin_right = 8
	st_cam.content_margin_top = 6
	st_cam.content_margin_bottom = 6
	frame.add_theme_stylebox_override("panel", st_cam)
	vbox.add_child(frame)

	var cam_box := VBoxContainer.new()
	cam_box.add_theme_constant_override("separation", 4)
	frame.add_child(cam_box)

	_lbl_marte_cam_estado = Label.new()
	_lbl_marte_cam_estado.text = "CAM 02 / EN LÍNEA"
	if _font_mono:
		_lbl_marte_cam_estado.add_theme_font_override("font", _font_mono)
	_lbl_marte_cam_estado.add_theme_font_size_override("font_size", 10)
	_lbl_marte_cam_estado.add_theme_color_override("font_color", Color("#4CE0B3"))
	cam_box.add_child(_lbl_marte_cam_estado)

	_tex_marte = TextureRect.new()
	_tex_marte.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tex_marte.custom_minimum_size = Vector2(0, 110)
	_tex_marte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_marte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_marte.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cam_box.add_child(_tex_marte)

	_lbl_marte_titulo = Label.new()
	_lbl_marte_titulo.text = "Base estable · Tierra visible"
	if _font_pixel:
		_lbl_marte_titulo.add_theme_font_override("font", _font_pixel)
	_lbl_marte_titulo.add_theme_font_size_override("font_size", 13)
	_lbl_marte_titulo.add_theme_color_override("font_color", Color("#F0F4F8"))
	_lbl_marte_titulo.clip_text = true
	_lbl_marte_titulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(_lbl_marte_titulo)

	_lbl_marte_sub = Label.new()
	_lbl_marte_sub.text = "Horizonte despejado · Enlace activo"
	if _font_mono:
		_lbl_marte_sub.add_theme_font_override("font", _font_mono)
	_lbl_marte_sub.add_theme_font_size_override("font_size", 10)
	_lbl_marte_sub.add_theme_color_override("font_color", Color("#6B7F99"))
	_lbl_marte_sub.clip_text = true
	_lbl_marte_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(_lbl_marte_sub)


func _actualizar_camara_marte() -> void:
	if _tex_marte == null:
		return
	var hay_senal: bool = GameManager.signal_active
	var bloqueo: Dictionary = GameManager.get_blocking_event()
	var tormenta: bool = GameManager.tiene_falla("m_polvo")

	if not hay_senal:
		_lbl_marte_cam_estado.text = "CAM 02 / SEÑAL DÉBIL"
		_lbl_marte_cam_estado.add_theme_color_override("font_color", Color("#F2B84B"))
	elif not bloqueo.is_empty():
		_lbl_marte_cam_estado.text = "CAM 02 / ALERTA BASE"
		_lbl_marte_cam_estado.add_theme_color_override("font_color", Color("#E05A47"))
	else:
		_lbl_marte_cam_estado.text = "CAM 02 / EN LÍNEA"
		_lbl_marte_cam_estado.add_theme_color_override("font_color", Color("#4CE0B3"))

	if not bloqueo.is_empty():
		_lbl_marte_titulo.text = str(bloqueo.get("titulo", "Emergencia en base"))
		_lbl_marte_sub.text = "Requiere atención inmediata"
	elif tormenta:
		_lbl_marte_titulo.text = "Tormenta de polvo"
		_lbl_marte_sub.text = "Visibilidad reducida en sector"
	elif not hay_senal:
		_lbl_marte_titulo.text = "Enlace orbital intermitente"
		_lbl_marte_sub.text = "Tierra visible en horizonte"
	else:
		_lbl_marte_titulo.text = "Base estable · Tierra visible"
		_lbl_marte_sub.text = "Sector Elysium · Sol %d" % GameManager.current_sol

	_tex_marte.texture = _dibujar_marte_pixel()


func _dibujar_marte_pixel() -> ImageTexture:
	var W := 96
	var H := 64
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)

	var sky_top := Color("#070B14")
	var sky_mid := Color("#101726")
	var sky_hor := Color("#261922")
	var ridge_far := Color("#3D1E20")
	var ridge_mid := Color("#572824")
	var sand_dark := Color("#6E3023")
	var sand_mid := Color("#8F3F2B")
	var sand_light := Color("#B35336")
	var rock_col := Color("#421B16")

	var hull_light := Color("#CBD5E1")
	var hull_mid := Color("#8FA3B8")
	var hull_dark := Color("#334155")
	var solar_blue := Color("#1D4ED8")
	var solar_dark := Color("#0F172A")
	var amber := Color("#F2B84B")
	var teal := Color("#4CE0B3")
	var alert_red := Color("#E05A47")

	var en_alerta: bool = not GameManager.get_blocking_event().is_empty()
	var tormenta: bool = GameManager.tiene_falla("m_polvo")

	# 1. Cielo marciano degradado
	img.fill(sky_top)
	img.fill_rect(Rect2i(0, 18, W, 16), sky_mid)
	img.fill_rect(Rect2i(0, 32, W, 12), sky_hor)

	# 2. Estrellas tenues
	var estrellas := [
		Vector2i(10, 6), Vector2i(24, 11), Vector2i(39, 5), Vector2i(52, 13),
		Vector2i(61, 7), Vector2i(86, 8), Vector2i(90, 19), Vector2i(46, 21),
		Vector2i(17, 19), Vector2i(83, 24)
	]
	for p in estrellas:
		img.set_pixel(p.x, p.y, Color("#94A3B8"))
	img.set_pixel(39, 5, Color("#F8FAFC"))
	img.set_pixel(86, 8, Color("#F8FAFC"))

	# 3. La Tierra vista a lo lejos en el cielo + la Luna
	var ex := 72
	var ey := 14
	# Halo atmosférico tenue
	for dx in range(-1, 6):
		for dy in range(-1, 6):
			var px := ex + dx
			var py := ey + dy
			if px >= 0 and px < W and py >= 0 and py < H:
				img.set_pixel(px, py, Color("#172B49"))
	# Disco de la Tierra (5x5 pixel art)
	img.fill_rect(Rect2i(ex + 1, ey, 3, 5), Color("#2563EB"))
	img.fill_rect(Rect2i(ex, ey + 1, 5, 3), Color("#2563EB"))
	img.fill_rect(Rect2i(ex + 1, ey + 1, 3, 3), Color("#38BDF8"))
	# Continentes y nubes
	img.set_pixel(ex + 1, ey + 1, Color("#4ADE80"))
	img.set_pixel(ex + 2, ey + 2, Color("#4ADE80"))
	img.set_pixel(ex + 3, ey + 2, Color("#D97706"))
	img.set_pixel(ex + 2, ey, Color("#F8FAFC"))
	img.set_pixel(ex + 3, ey + 3, Color("#F8FAFC"))
	# La Luna a un costado
	img.set_pixel(ex + 8, ey - 2, Color("#CBD5E1"))

	# 4. Cordilleras lejanas de Marte
	for x in range(W):
		var h_far := 38 + int(sin(float(x) * 0.09) * 3.0 + cos(float(x) * 0.21) * 1.5)
		img.fill_rect(Rect2i(x, h_far, 1, 46 - h_far), ridge_far)
		var h_mid := 41 + int(cos(float(x) * 0.07 + 1.2) * 2.5 + sin(float(x) * 0.17) * 1.5)
		img.fill_rect(Rect2i(x, h_mid, 1, 48 - h_mid), ridge_mid)

	# 5. Terreno marciano y dunas
	img.fill_rect(Rect2i(0, 46, W, H - 46), sand_mid)
	img.fill_rect(Rect2i(0, 54, W, H - 54), sand_dark)
	# Relieves y sombras de dunas
	img.fill_rect(Rect2i(36, 48, 28, 2), sand_light)
	img.fill_rect(Rect2i(68, 51, 24, 2), sand_light)
	img.fill_rect(Rect2i(6, 56, 32, 2), sand_mid)
	img.fill_rect(Rect2i(50, 58, 38, 2), sand_mid)
	# Cráter y rocas marcianas
	img.fill_rect(Rect2i(64, 55, 12, 3), sand_dark)
	img.fill_rect(Rect2i(66, 56, 8, 1), rock_col)
	img.fill_rect(Rect2i(55, 51, 3, 2), rock_col)
	img.fill_rect(Rect2i(82, 59, 4, 2), rock_col)
	img.fill_rect(Rect2i(44, 60, 2, 2), rock_col)

	# 6. Hábitat / Base Marciana (lado izquierdo para dejar despejada la Tierra)
	# Antena de comunicaciones
	img.fill_rect(Rect2i(14, 30, 1, 9), hull_mid)
	img.fill_rect(Rect2i(12, 32, 5, 1), hull_light)
	var col_faro := alert_red if en_alerta else teal
	if _marte_blink:
		img.set_pixel(14, 29, col_faro)
	else:
		img.set_pixel(14, 29, hull_dark)

	# Domo principal del hábitat
	img.fill_rect(Rect2i(10, 39, 18, 2), hull_mid)
	img.fill_rect(Rect2i(8, 41, 22, 10), hull_light)
	img.fill_rect(Rect2i(24, 41, 6, 10), hull_mid)
	img.fill_rect(Rect2i(7, 50, 24, 2), hull_dark)

	# Esclusa / compuerta y ventanas iluminadas
	img.fill_rect(Rect2i(17, 45, 5, 6), hull_dark)
	img.fill_rect(Rect2i(18, 46, 3, 4), Color("#1E293B"))
	var col_ventana := alert_red if en_alerta else amber
	img.fill_rect(Rect2i(11, 43, 3, 2), col_ventana)
	img.fill_rect(Rect2i(24, 43, 3, 2), col_ventana)

	# Paneles solares desplegados junto al módulo
	img.fill_rect(Rect2i(30, 48, 3, 2), hull_dark)
	img.fill_rect(Rect2i(33, 45, 12, 5), solar_dark)
	img.fill_rect(Rect2i(34, 46, 4, 3), solar_blue)
	img.fill_rect(Rect2i(40, 46, 4, 3), solar_blue)
	img.fill_rect(Rect2i(36, 50, 1, 2), hull_dark)
	img.fill_rect(Rect2i(42, 50, 1, 2), hull_dark)

	# Pequeño rover explorador junto a la base
	img.fill_rect(Rect2i(48, 52, 5, 2), hull_light)
	img.set_pixel(49, 54, hull_dark)
	img.set_pixel(52, 54, hull_dark)
	img.set_pixel(51, 51, teal)

	# 7. Efecto atmosférico si hay tormenta de polvo o señal débil
	if tormenta:
		for y in range(H):
			for x in range(W):
				var base_c := img.get_pixel(x, y)
				img.set_pixel(x, y, base_c.lerp(Color("#B85638"), 0.36))
			if y % 5 == 0:
				var sx := (y * 7 + (12 if _marte_blink else 0)) % (W - 14)
				img.fill_rect(Rect2i(sx, y, 14, 1), Color("#D97742"))
	elif not GameManager.signal_active:
		for y in range(0, H, 4):
			var off := 6 if _marte_blink else 0
			for x in range(off, W, 12):
				img.set_pixel(x, y, Color("#64748B"))

	return ImageTexture.create_from_image(img)
