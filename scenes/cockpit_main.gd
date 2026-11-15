extends Control
## res://scenes/cockpit_main.gd

@onready var contenedor_central: PanelContainer = $VBoxPrincipal/CuerpoMonitor/ContenedorCentral
@onready var ventana_notas: Panel = $VentanaNotas
@onready var label_presupuesto: Label = $VBoxPrincipal/BarraSuperior/LabelPresupuesto
@onready var icono_senal: Label = $VBoxPrincipal/BarraSuperior/IconoSenal
@onready var btn_siguiente_dia: Button = $VBoxPrincipal/BarraSuperior/BtnSiguienteDia

@onready var btn_comprar: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnComprar
@onready var btn_mantenimiento: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnMantenimiento
@onready var btn_diseno: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnDiseno
@onready var btn_lanzamiento: Button = $VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnLanzamiento

# Rutas (no preload): si una escena aún no existe, se muestra un placeholder
# en vez de romper todo el script al abrirlo.
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
	# Textos de los botones (en el .tscn estaban vacíos)
	btn_comprar.text = TITULOS_MENU["comprar"]
	btn_mantenimiento.text = TITULOS_MENU["mantenimiento"]
	btn_diseno.text = TITULOS_MENU["diseno"]
	btn_lanzamiento.text = TITULOS_MENU["lanzamiento"]

	# El visor central debe ocupar todo el espacio disponible
	contenedor_central.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Conectar botones del menú
	btn_comprar.pressed.connect(cambiar_menu.bind("comprar"))
	btn_mantenimiento.pressed.connect(cambiar_menu.bind("mantenimiento"))
	btn_diseno.pressed.connect(cambiar_menu.bind("diseno"))
	btn_lanzamiento.pressed.connect(cambiar_menu.bind("lanzamiento"))

	# Barra superior
	$VBoxPrincipal/BarraSuperior/BtnNotas.pressed.connect(func(): ventana_notas.visible = !ventana_notas.visible)
	btn_siguiente_dia.pressed.connect(_on_siguiente_dia_pressed)
	ventana_notas.visible = false

	# Escuchar cambios globales
	Events.resources_updated.connect(_actualizar_barra_superior)
	Events.signal_status_changed.connect(_actualizar_senal)
	Events.sol_advanced.connect(_on_sol_advanced)

	# Estado inicial
	_actualizar_barra_superior()
	_actualizar_senal(GameManager.signal_active)
	_actualizar_boton_dia()
	cambiar_menu("comprar")


func cambiar_menu(clave: String) -> void:
	# Quitar el menú anterior YA (remove_child) para que no se solapen un frame
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


func _on_siguiente_dia_pressed() -> void:
	GameManager.advance_sol()


func _on_sol_advanced(_nuevo_sol: int) -> void:
	_actualizar_boton_dia()
	_actualizar_barra_superior()


func _actualizar_boton_dia() -> void:
	btn_siguiente_dia.text = "Siguiente Día (Sol %d)" % GameManager.current_sol


func _actualizar_barra_superior() -> void:
	label_presupuesto.text = "$ %d | Raciones: %.1f" % [GameManager.budget, GameManager.food_rations]


func _actualizar_senal(esta_en_linea: bool) -> void:
	icono_senal.text = "SEÑAL: ACTIVA" if esta_en_linea else "SIN SEÑAL"
