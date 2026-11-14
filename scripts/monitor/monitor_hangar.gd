extends PanelContainer
## Marco de la cámara del hangar. Adjuntar a CamaraTierraContainer.

const VisorScript = preload("res://scripts/monitor/visor_complejo_tierra.gd")

const ESTADOS: PackedStringArray = [
	"Plataforma lista — Sin nave",
	"Tanque y motores instalados",
	"Propulsores laterales acoplados",
	"Fuselaje y cabina ensamblados",
	"Nave espacial lista en plataforma",
]

const PIEZAS_PRUEBA: Array[Dictionary] = [
	{"nombre": "Vehículo de lanzamiento", "categoria": SpacecraftPart.Category.LAUNCH_VEHICLE},
	{"nombre": "Propulsión principal", "categoria": SpacecraftPart.Category.PROPULSION},
	{"nombre": "Sistema de energía", "categoria": SpacecraftPart.Category.POWER_SYSTEM},
	{"nombre": "Instrumento científico", "categoria": SpacecraftPart.Category.SCIENCE_INSTRUMENT},
]

@export var teclas_de_prueba: bool = true

var _visor: Control
var _estado_cam: Label
var _nombre_pieza: Label
var _contador: Label
var _fuente_regular: Font
var _fuente_negrita: Font


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_END
	add_theme_stylebox_override("panel", _estilo_caja())
	_preparar_fuentes()
	_armar()
	if not Events.resources_updated.is_connected(_refrescar):
		Events.resources_updated.connect(_refrescar)
	if not Events.signal_status_changed.is_connected(_al_cambiar_senal):
		Events.signal_status_changed.connect(_al_cambiar_senal)
	_refrescar()
	call_deferred("_anclar_al_fondo")


func _process(_delta: float) -> void:
	if _estado_cam == null:
		return
	if GameManager.has_signal:
		var pulso := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 180.0)
		_estado_cam.modulate = Color(1, 1, 1, pulso)
	else:
		_estado_cam.modulate = Color.WHITE


func _armar() -> void:
	if get_node_or_null("ContenidoHangar") != null:
		return
	var raiz := VBoxContainer.new()
	raiz.name = "ContenidoHangar"
	raiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raiz.size_flags_vertical = Control.SIZE_SHRINK_END
	raiz.add_theme_constant_override("separation", 4)
	add_child(raiz)

	var cabecera := VBoxContainer.new()
	cabecera.size_flags_vertical = Control.SIZE_SHRINK_END
	cabecera.add_theme_constant_override("separation", 2)
	cabecera.add_child(_texto("CÁMARA DEL HANGAR", 13, Color("#F0F4F8"), true))
	cabecera.add_child(_texto("TIERRA / COMPLEJO ATLAS", 10, Color("#6C7E96"), false))
	raiz.add_child(cabecera)

	var marco := Panel.new()
	marco.name = "MarcoVisor"
	marco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marco.size_flags_vertical = Control.SIZE_SHRINK_END
	marco.custom_minimum_size = Vector2(0, 165)
	marco.clip_contents = true
	marco.add_theme_stylebox_override("panel", _estilo_marco())
	raiz.add_child(marco)

	_visor = get_node_or_null("VisorComplejo") as Control
	if _visor == null:
		_visor = VisorScript.new()
		_visor.name = "VisorComplejo"
	else:
		if _visor.get_script() == null:
			_visor.set_script(VisorScript)
		_visor.get_parent().remove_child(_visor)
	_visor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visor.size_flags_vertical = Control.SIZE_SHRINK_END
	_visor.custom_minimum_size = Vector2(0, 165)
	_visor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visor.offset_left = 1.0
	_visor.offset_top = 1.0
	_visor.offset_right = -1.0
	_visor.offset_bottom = -1.0
	marco.add_child(_visor)

	_estado_cam = _texto("CAM 01  /  EN LÍNEA", 11, Color("#4ADE80"), true)
	_estado_cam.position = Vector2(8, 6)
	_estado_cam.z_index = 2
	marco.add_child(_estado_cam)

	var pie := VBoxContainer.new()
	pie.size_flags_vertical = Control.SIZE_SHRINK_END
	pie.add_theme_constant_override("separation", 2)
	_nombre_pieza = _texto("Plataforma lista — Sin nave", 13, Color("#F0F4F8"), true)
	_nombre_pieza.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pie.add_child(_nombre_pieza)
	pie.add_child(_texto("PROGRESO DE ENSAMBLAJE", 10, Color("#6C7E96"), false))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	_contador = _texto("0", 20, Color("#F2B84B"), true)
	fila.add_child(_contador)
	var sistemas := _texto("/ 4 SISTEMAS", 12, Color("#F0F4F8"), true)
	sistemas.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	sistemas.size_flags_vertical = Control.SIZE_SHRINK_END
	fila.add_child(sistemas)
	pie.add_child(fila)
	pie.add_child(_texto("El hangar cambia al terminar piezas.", 11, Color("#6C7E96"), false))
	raiz.add_child(pie)


func _anclar_al_fondo() -> void:
	var padre := get_parent()
	if padre == null or not padre is BoxContainer:
		return
	var espacio := padre.get_node_or_null("EspaciadorHangar") as Control
	if espacio == null:
		espacio = Control.new()
		espacio.name = "EspaciadorHangar"
		espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE
		espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
		padre.add_child(espacio)
		padre.move_child(espacio, get_index())


func _al_cambiar_senal(_activa: bool) -> void:
	_refrescar()


func _refrescar() -> void:
	var cantidad := mini(GameManager.equipped_parts.size(), 4)
	var en_linea := GameManager.has_signal
	if _visor != null and _visor.has_method("establecer_estado"):
		_visor.establecer_estado(cantidad, en_linea)
	if _contador != null:
		_contador.text = str(cantidad)
	if _nombre_pieza != null:
		_nombre_pieza.text = _nombre_de_estado(cantidad)
	if _estado_cam != null:
		if en_linea:
			_estado_cam.text = "CAM 01  /  EN LÍNEA"
			_estado_cam.add_theme_color_override("font_color", Color("#4ADE80"))
		else:
			_estado_cam.text = "CAM 01  /  SIN ENLACE"
			_estado_cam.add_theme_color_override("font_color", Color("#E05A47"))


func _nombre_de_estado(cantidad: int) -> String:
	return ESTADOS[clampi(cantidad, 0, ESTADOS.size() - 1)]


func _unhandled_input(evento: InputEvent) -> void:
	if not teclas_de_prueba or not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_F9:
			_construir_pieza_de_prueba()
		KEY_F10:
			_reiniciar_complejo()
		_:
			return
	get_viewport().set_input_as_handled()


func _construir_pieza_de_prueba() -> void:
	var cantidad := GameManager.equipped_parts.size()
	if cantidad >= 4:
		print("[Hangar] El complejo ya tiene 4 sistemas.")
		return
	var datos: Dictionary = PIEZAS_PRUEBA[cantidad]
	var parte := SpacecraftPart.new()
	parte.part_name = str(datos["nombre"])
	parte.category = datos["categoria"]
	parte.budget_cost = 0
	if GameManager.equip_part(parte):
		print("[Hangar] Sistema %d/4: %s" % [mini(GameManager.equipped_parts.size(), 4), parte.part_name])
	else:
		print("[Hangar] No se pudo equipar la pieza de prueba.")


func _reiniciar_complejo() -> void:
	GameManager.equipped_parts.clear()
	GameManager.recalculate_engineering_stats()
	Events.resources_updated.emit()
	print("[Hangar] Complejo reiniciado a 0/4.")


func _preparar_fuentes() -> void:
	_fuente_regular = SystemFont.new()
	_fuente_regular.font_names = PackedStringArray(["Segoe UI", "Arial"])
	_fuente_regular.font_weight = 400
	_fuente_negrita = SystemFont.new()
	_fuente_negrita.font_names = PackedStringArray(["Segoe UI", "Arial"])
	_fuente_negrita.font_weight = 700


func _texto(mensaje: String, tamano: int, color: Color, negrita: bool) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = mensaje
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_override("font", _fuente_negrita if negrita else _fuente_regular)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta


func _estilo_caja() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#0B101B")
	estilo.border_color = Color("#1E2D42")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(10)
	estilo.anti_aliasing = false
	return estilo


func _estilo_marco() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#060911")
	estilo.border_color = Color("#1E2D42")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(2)
	estilo.anti_aliasing = false
	return estilo
