extends VBoxContainer
## Caja superior "PRÓXIMOS EVENTOS". Adjuntar a CalendarioTareas.

const Gestor = preload("res://scripts/calendario/gestor_calendario.gd")
const RANURAS := 3

var _tarjetas: VBoxContainer
var _fondo: StyleBoxFlat


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_stretch_ratio = 0.46
	custom_minimum_size = Vector2.ZERO
	add_theme_constant_override("separation", 0)
	_fondo = Gestor.estilo_panel()
	_fondo.set_content_margin_all(0)
	var panel := get_parent() as BoxContainer
	if panel != null:
		panel.add_theme_constant_override("separation", 14)
	_armar()
	_conectar()
	_reconstruir()


func _draw() -> void:
	if _fondo != null:
		_fondo.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))


func _armar() -> void:
	if _tarjetas != null:
		return

	var margen := MarginContainer.new()
	margen.name = "MargenEventos"
	margen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_bottom", 12)
	add_child(margen)

	var interior := VBoxContainer.new()
	interior.name = "InteriorEventos"
	interior.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interior.size_flags_vertical = Control.SIZE_EXPAND_FILL
	interior.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interior.add_theme_constant_override("separation", 10)
	margen.add_child(interior)

	var cabecera := VBoxContainer.new()
	cabecera.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cabecera.add_theme_constant_override("separation", 1)
	cabecera.add_child(_texto("PRÓXIMOS EVENTOS", 13, Gestor.COLOR_TEXTO, true))
	cabecera.add_child(_texto("ORDEN CRONOLÓGICO", 10, Gestor.COLOR_NOTA, false))
	interior.add_child(cabecera)

	_tarjetas = VBoxContainer.new()
	_tarjetas.name = "TarjetasEventos"
	_tarjetas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tarjetas.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tarjetas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tarjetas.add_theme_constant_override("separation", 10)
	interior.add_child(_tarjetas)

	var espaciador := Control.new()
	espaciador.name = "EspaciadorNota"
	espaciador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	espaciador.size_flags_vertical = Control.SIZE_EXPAND_FILL
	interior.add_child(espaciador)

	var pie := _texto("Cada pedido y trabajo agrega su fecha al calendario.", 11, Gestor.COLOR_NOTA, false)
	pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interior.add_child(pie)


func _conectar() -> void:
	var gestor = Gestor.obtener()
	if not gestor.eventos_actualizados.is_connected(_reconstruir):
		gestor.eventos_actualizados.connect(_reconstruir)
	if not gestor.tiempo_actualizado.is_connected(_al_mover_el_tiempo):
		gestor.tiempo_actualizado.connect(_al_mover_el_tiempo)
	if not Events.sol_advanced.is_connected(_al_mover_el_tiempo):
		Events.sol_advanced.connect(_al_mover_el_tiempo)


func _al_mover_el_tiempo(_dia: int) -> void:
	_reconstruir()


func _reconstruir() -> void:
	if _tarjetas == null:
		return
	for hijo in _tarjetas.get_children():
		_tarjetas.remove_child(hijo)
		hijo.free()
	for ranura in _ranuras():
		_tarjetas.add_child(_crear_tarjeta(ranura))


func _ranuras() -> Array:
	var activas: Array = []
	for evento in Gestor.obtener().eventos_pendientes():
		activas.append(evento)
	var limite := {
		"dia": GameManager.MAX_SOLS,
		"titulo": "Límite de reservas",
		"fijo": true,
	}
	activas.append(limite)
	if activas.size() > RANURAS:
		var visibles: Array = []
		visibles.append(activas[0])
		visibles.append(activas[1])
		visibles.append(limite)
		activas = visibles
	while activas.size() < RANURAS:
		activas.append({"vacia": true})
	return activas


func _crear_tarjeta(ranura: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 62
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _estilo_tarjeta())

	var caja := VBoxContainer.new()
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_theme_constant_override("separation", 2)
	panel.add_child(caja)

	var dia_texto := "-"
	var titulo := "Sin más eventos"
	var titulo_apagado := true
	if not bool(ranura.get("vacia", false)):
		dia_texto = str(int(ranura["dia"]))
		titulo = str(ranura["titulo"])
		titulo_apagado = false

	caja.add_child(_linea_dia(dia_texto))
	var color_titulo := Gestor.COLOR_TEXTO
	if titulo_apagado:
		color_titulo.a = 0.45
	var etiqueta_titulo := _texto(titulo, 12, color_titulo, not titulo_apagado)
	etiqueta_titulo.clip_text = true
	etiqueta_titulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caja.add_child(etiqueta_titulo)
	return panel


func _linea_dia(dia_texto: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 0)
	var prefijo := _texto("DÍA ", 11, Gestor.COLOR_NOTA, false)
	var numero := _texto(dia_texto, 11, Gestor.COLOR_ORO, true)
	prefijo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	numero.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	prefijo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(prefijo)
	fila.add_child(numero)
	return fila


func _estilo_tarjeta() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Gestor.COLOR_TARJETA
	estilo.border_color = Gestor.COLOR_BORDE_TARJETA
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 12
	estilo.content_margin_bottom = 12
	estilo.anti_aliasing = false
	return estilo


func _texto(mensaje: String, tamano: int, color: Color, negrita: bool) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = mensaje
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_override("font", Gestor.fuente(negrita))
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return etiqueta
