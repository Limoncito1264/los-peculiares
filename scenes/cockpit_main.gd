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
	"comprar": "Comprar",
	"mantenimiento": "Mantenimiento",
	"diseno": "Diseño",
	"lanzamiento": "Lanzamiento",
}


func _ready() -> void:
	_aplicar_estilo_ares()

	btn_comprar.text = TITULOS_MENU["comprar"]
	btn_mantenimiento.text = TITULOS_MENU["mantenimiento"]
	btn_diseno.text = TITULOS_MENU["diseno"]
	btn_lanzamiento.text = TITULOS_MENU["lanzamiento"]

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
