extends Control

@onready var contenedor_central: PanelContainer = $VBoxPrincipal/CuerpoMonitor/ContenedorCentral
@onready var ventana_notas: Panel = $VentanaNotas
@onready var label_presupuesto: Label = $VBoxPrincipal/BarraSuperior/LabelPresupuesto
@onready var icono_senal: Label = $VBoxPrincipal/BarraSuperior/IconoSenal
@onready var btn_siguiente_dia: Button = $VBoxPrincipal/BarraSuperior/BtnSiguienteDia

# Precargamos las 4 escenas centrales (crea archivos vacíos con esos nombres si aún no existen)
var escenas_menu := {
	"comprar": preload("res://scenes/tab_shop.tscn"),
	"mantenimiento": preload("res://scenes/tab_maintenance.tscn"),
	"diseno": preload("res://scenes/tab_design.tscn"),
	"lanzamiento": preload("res://scenes/tab_launch.tscn")
}

func _ready() -> void:
	# Conectar botones de arriba a la derecha
	$VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnComprar.pressed.connect(func(): cambiar_menu("comprar"))
	$VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnMantenimiento.pressed.connect(func(): cambiar_menu("mantenimiento"))
	$VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnDiseno.pressed.connect(func(): cambiar_menu("diseno"))
	$VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnLanzamiento.pressed.connect(func(): cambiar_menu("lanzamiento"))
	$VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnComprar.text = "Comprar"
	$VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnMantenimiento.text = "Mantenimiento"
	$VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnDiseno.text = "Diseño"
	$VBoxPrincipal/CuerpoMonitor/PanelDerecho/BotonesMenu/BtnLanzamiento.text = "Lanzamiento"
	btn_siguiente_dia.text = "Siguiente Día (Sol %d)" % GameManager.current_sol
	# Conectar barra superior
	$VBoxPrincipal/BarraSuperior/BtnNotas.pressed.connect(func(): ventana_notas.visible = !ventana_notas.visible)
	btn_siguiente_dia.pressed.connect(_on_siguiente_dia_pressed)
	
	# Escuchar cambios globales
	Events.resources_updated.connect(_actualizar_barra_superior)
	Events.signal_status_changed.connect(_actualizar_senal)
	
	_actualizar_barra_superior()
	cambiar_menu("comprar")

func cambiar_menu(clave: String) -> void:
	# Borra el menú anterior del centro
	for hijo in contenedor_central.get_children():
		hijo.queue_free()
	
	# Instancia el nuevo menú seleccionado
	var nueva_escena = escenas_menu[clave].instantiate()
	contenedor_central.add_child(nueva_escena)

func _on_siguiente_dia_pressed() -> void:
	GameManager.advance_sol()
	btn_siguiente_dia.text = "Siguiente Día (Sol %d)" % GameManager.current_sol

func _actualizar_barra_superior() -> void:
	label_presupuesto.text = "$ %d | Raciones: %.1f" % [GameManager.budget, GameManager.food_rations]

func _actualizar_senal(esta_en_linea: bool) -> void:
	icono_senal.text = "SEÑAL: ACTIVA" if esta_en_linea else "SIN SEÑAL"
