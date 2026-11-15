extends Control
## res://scenes/cockpit_main.gd

@onready var contenedor_central: PanelContainer = $VBoxPrincipal/CuerpoMonitor/ContenedorCentral
@onready var ventana_notas: Panel = $VentanaNotas

@onready var lbl_sol_contador: Label = $VBoxPrincipal/HeaderSuperior/FilaArriba/CajaSolActual/LblSolContador
@onready var btn_siguiente_sol: Button = $VBoxPrincipal/HeaderSuperior/FilaArriba/CentroBotonSol/BtnSiguienteSol
@onready var lbl_dinero_valor: Label = $VBoxPrincipal/HeaderSuperior/FilaArriba/CajaDinero/LblDineroValor
@onready var btn_notas: Button = $VBoxPrincipal/HeaderSuperior/FilaArriba/BtnNotas

@onready var lbl_plazo_valor: Label = $VBoxPrincipal/HeaderSuperior/FilaTarjetas/CardPlazo/VBox/LblValor
@onready var lbl_senal_valor: Label = $VBoxPrincipal/HeaderSuperior/FilaTarjetas/CardSenal/VBox/LblValor
@onready var lbl_electricidad_valor: Label = $VBoxPrincipal/HeaderSuperior/FilaTarjetas/CardElectricidad/VBox/LblValor

@onready var btn_comprar: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnComprar
@onready var btn_mantenimiento: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnMantenimiento
@onready var btn_diseno: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnDiseno
@onready var btn_lanzamiento: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnLanzamiento

const RUTAS_MENU := {
	"comprar": "res://scenes/tab_materials.tscn",
	"mantenimiento": "res://scenes/tab_maintenance.tscn",
	"diseno": "res://scenes/tab_design.tscn",
	"lanzamiento": "res://scenes/tab_launch.tscn",
}
const TITULOS_MENU := {
	"comprar": "Materiales",
	"mantenimiento": "Mantenimiento",
	"diseno": "Diseño",
	"lanzamiento": "Lanzamiento",
}

var _botones_modulo := {}
var _estilo_mod_normal: StyleBoxFlat
var _estilo_mod_activo: StyleBoxFlat


func _ready() -> void:
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
	GameManager.state_changed.connect(_actualizar_header)

	_actualizar_header()
	_actualizar_senal(GameManager.signal_active)
	cambiar_menu("comprar")


func cambiar_menu(clave: String) -> void:
	for k in _botones_modulo:
		var b: Button = _botones_modulo[k]
		b.add_theme_stylebox_override("normal", _estilo_mod_activo if k == clave else _estilo_mod_normal)

	for hijo in contenedor_central.get_children():
		contenedor_central.remove_child(hijo)
		hijo.queue_free()

	var ruta: String = RUTAS_MENU[clave]
	var nueva: Control
	if ResourceLoader.exists(ruta):
		nueva = (load(ruta) as PackedScene).instantiate()
	else:
		nueva = _crear_placeholder(clave)
	contenedor_central.add_child(nueva)


func _crear_placeholder(clave: String) -> Control:
	var lbl := Label.new()
	lbl.text = "%s\n(en construcción)" % TITULOS_MENU[clave]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


func _on_siguiente_sol_pressed() -> void:
	GameManager.advance_sol()
	_actualizar_header()


func _actualizar_header() -> void:
	var sol_actual: int = GameManager.current_sol
	var soles_restantes: int = max(0, 60 - sol_actual)

	lbl_sol_contador.text = "SOL %d / 60" % sol_actual
	lbl_plazo_valor.text = "%d / 60 SOLES" % soles_restantes
	lbl_dinero_valor.text = "%d CR" % GameManager.budget

	var baja_energia: bool = GameManager.tiene_falla("mars_solar_dust")
	lbl_electricidad_valor.text = "35% · AHORRO" if baja_energia else "88% · OPERATIVA"
	lbl_electricidad_valor.modulate = Color("#F2B84B") if baja_energia else Color("#4CE0B3")
	btn_notas.disabled = baja_energia
	if baja_energia:
		ventana_notas.visible = false


func _actualizar_senal(esta_en_linea: bool) -> void:
	if esta_en_linea:
		lbl_senal_valor.text = "100% · ESTABLE"
		lbl_senal_valor.modulate = Color("#4CE0B3")
	else:
		lbl_senal_valor.text = "0% · SIN SEÑAL"
		lbl_senal_valor.modulate = Color("#FF5C5C")


func _aplicar_estilo_ares() -> void:
	if ResourceLoader.exists("res://themes/ares_theme.tres"):
		$VBoxPrincipal.theme = load("res://themes/ares_theme.tres")

	var estilo_btn := StyleBoxFlat.new()
	estilo_btn.bg_color = Color("#F2B84B")
	estilo_btn.set_corner_radius_all(3)
	estilo_btn.content_margin_left = 24
	estilo_btn.content_margin_right = 24
	estilo_btn.content_margin_top = 10
	estilo_btn.content_margin_bottom = 10

	btn_siguiente_sol.add_theme_stylebox_override("normal", estilo_btn)
	btn_siguiente_sol.add_theme_color_override("font_color", Color("#0B111A"))
	lbl_dinero_valor.modulate = Color("#F2B84B")

	var estilo_card := StyleBoxFlat.new()
	estilo_card.bg_color = Color("#101824")
	estilo_card.border_color = Color("#22324A")
	estilo_card.set_border_width_all(1)
	estilo_card.content_margin_left = 12
	estilo_card.content_margin_right = 12
	estilo_card.content_margin_top = 8
	estilo_card.content_margin_bottom = 8

	for card in $VBoxPrincipal/HeaderSuperior/FilaTarjetas.get_children():
		if card is PanelContainer:
			card.add_theme_stylebox_override("panel", estilo_card)

	_estilizar_modulos_derecha()


func _estilizar_modulos_derecha() -> void:
	var panel_der: VBoxContainer = $VBoxPrincipal/CuerpoMonitor/PanelDerecho
	var grid: GridContainer = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu

	panel_der.custom_minimum_size.x = 290
	panel_der.add_theme_constant_override("separation", 8)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

	if not panel_der.has_node("LblModulosMision"):
		var lbl_sec := Label.new()
		lbl_sec.name = "LblModulosMision"
		lbl_sec.text = "MÓDULOS DE MISIÓN"
		lbl_sec.add_theme_font_size_override("font_size", 11)
		lbl_sec.add_theme_color_override("font_color", Color("#7C8FA6"))
		panel_der.add_child(lbl_sec)
		panel_der.move_child(lbl_sec, 0)

	_estilo_mod_normal = StyleBoxFlat.new()
	_estilo_mod_normal.bg_color = Color("#101824")
	_estilo_mod_normal.border_color = Color("#22324A")
	_estilo_mod_normal.set_border_width_all(1)

	var estilo_hover := StyleBoxFlat.new()
	estilo_hover.bg_color = Color("#152234")
	estilo_hover.border_color = Color("#4CE0B3")
	estilo_hover.set_border_width_all(1)

	_estilo_mod_activo = StyleBoxFlat.new()
	_estilo_mod_activo.bg_color = Color("#132030")
	_estilo_mod_activo.border_color = Color("#4CE0B3")
	_estilo_mod_activo.set_border_width_all(1)

	_botones_modulo = {
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

	for item in config:
		var clave: String = item[0]
		var num: String = item[1]
		var titulo: String = item[2]
		var btn: Button = _botones_modulo[clave]

		btn.text = ""
		btn.custom_minimum_size = Vector2(0, 96)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		btn.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 4)
		margin.add_child(vbox)

		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(hbox)

		var tex_rect := TextureRect.new()
		tex_rect.texture = _crear_icono_modulo(clave)
		tex_rect.custom_minimum_size = Vector2(22, 22)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(tex_rect)

		var lbl_num := Label.new()
		lbl_num.text = num
		lbl_num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_num.add_theme_font_size_override("font_size", 11)
		lbl_num.add_theme_color_override("font_color", Color("#6B7F99"))
		lbl_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl_num)

		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(spacer)

		var lbl_tit := Label.new()
		lbl_tit.text = titulo
		lbl_tit.add_theme_font_size_override("font_size", 14)
		lbl_tit.add_theme_color_override("font_color", Color("#E8EEF5"))
		lbl_tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl_tit)

		var lbl_sub := Label.new()
		lbl_sub.text = "ABRIR MÓDULO"
		lbl_sub.add_theme_font_size_override("font_size", 10)
		lbl_sub.add_theme_color_override("font_color", Color("#6B7F99"))
		lbl_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl_sub)


func _crear_icono_modulo(clave: String) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color("#4CE0B3")

	match clave:
		"comprar":
			_dibujar_linea(img, 8, 2, 13, 5, c)
			_dibujar_linea(img, 13, 5, 8, 8, c)
			_dibujar_linea(img, 8, 8, 3, 5, c)
			_dibujar_linea(img, 3, 5, 8, 2, c)
			_dibujar_linea(img, 3, 5, 3, 11, c)
			_dibujar_linea(img, 8, 8, 8, 14, c)
			_dibujar_linea(img, 13, 5, 13, 11, c)
			_dibujar_linea(img, 3, 11, 8, 14, c)
			_dibujar_linea(img, 8, 14, 13, 11, c)
		"mantenimiento":
			_dibujar_linea(img, 3, 12, 10, 5, c)
			_dibujar_linea(img, 4, 13, 11, 6, c)
			_dibujar_linea(img, 9, 3, 12, 3, c)
			_dibujar_linea(img, 9, 3, 9, 5, c)
			_dibujar_linea(img, 13, 4, 13, 7, c)
			_dibujar_linea(img, 11, 7, 13, 7, c)
			_dibujar_linea(img, 2, 11, 4, 13, c)
		"diseno":
			_dibujar_linea(img, 4, 4, 11, 4, c)
			_dibujar_linea(img, 11, 4, 11, 11, c)
			_dibujar_linea(img, 11, 11, 4, 11, c)
			_dibujar_linea(img, 4, 11, 4, 4, c)
			_dibujar_linea(img, 6, 6, 9, 6, c)
			_dibujar_linea(img, 9, 6, 9, 9, c)
			_dibujar_linea(img, 9, 9, 6, 9, c)
			_dibujar_linea(img, 6, 9, 6, 6, c)
			_dibujar_linea(img, 7, 2, 8, 2, c)
			_dibujar_linea(img, 7, 13, 8, 13, c)
			_dibujar_linea(img, 2, 7, 2, 8, c)
			_dibujar_linea(img, 13, 7, 13, 8, c)
		"lanzamiento":
			_dibujar_linea(img, 13, 2, 10, 2, c)
			_dibujar_linea(img, 13, 2, 13, 5, c)
			_dibujar_linea(img, 10, 2, 6, 6, c)
			_dibujar_linea(img, 13, 5, 9, 9, c)
			_dibujar_linea(img, 6, 6, 6, 9, c)
			_dibujar_linea(img, 6, 9, 9, 9, c)
			_dibujar_linea(img, 6, 6, 3, 7, c)
			_dibujar_linea(img, 3, 7, 5, 9, c)
			_dibujar_linea(img, 9, 9, 8, 12, c)
			_dibujar_linea(img, 8, 12, 6, 10, c)
			_dibujar_linea(img, 3, 12, 4, 11, c)

	return ImageTexture.create_from_image(img)


func _dibujar_linea(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		if x >= 0 and x < 16 and y >= 0 and y < 16:
			img.set_pixel(x, y, col)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
