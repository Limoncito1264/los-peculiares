extends GridContainer
## Caja inferior "PLAN DE 60 DÍAS". Adjuntar a CalendarioMes.
## Las teclas de prueba siguen activas. Los botones de prueba nacen ocultos.

const Gestor = preload("res://scripts/calendario/gestor_calendario.gd")

@export var columnas: int = 10
@export var teclas_de_prueba: bool = true
@export var mostrar_botones_de_prueba: bool = false

var _celdas: Array[Button] = []
var _numero_actual: Label
var _contenido: VBoxContainer


func _ready() -> void:
	columns = maxi(columnas, 1)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("h_separation", 3)
	add_theme_constant_override("v_separation", 3)
	visible = false
	call_deferred("_montar")


func _montar() -> void:
	_envolver()
	_crear_celdas()
	_conectar()
	_refrescar()
	visible = true
	print("[Calendario] Teclas: F1 +1 día | F2 llegada | F3 fabricación | F4 emergencia | F6 saltar | F7 cancelar | F8 ejemplos")


func _envolver() -> void:
	var padre := get_parent()
	if padre == null or padre.name == "ContenidoPlan":
		_contenido = padre as VBoxContainer
		return

	for nombre in ["TituloCalendario", "LeyendaCalendario", "DetalleDia", "PruebasCalendario"]:
		var viejo := padre.get_node_or_null(nombre)
		if viejo != null:
			viejo.free()

	var indice := get_index()
	var caja := PanelContainer.new()
	caja.name = "CajaPlanDias"
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	caja.add_theme_stylebox_override("panel", Gestor.estilo_panel())

	_contenido = VBoxContainer.new()
	_contenido.name = "ContenidoPlan"
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_contenido.add_theme_constant_override("separation", 10)
	caja.add_child(_contenido)

	padre.add_child(caja)
	padre.move_child(caja, indice)
	padre.remove_child(self)
	_contenido.add_child(self)

	var cabecera := VBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 1)
	cabecera.add_child(_texto("PLAN DE 60 DÍAS", 13, Gestor.COLOR_TEXTO, true))
	cabecera.add_child(_texto("CADA CUADRO = 1 DÍA", 10, Gestor.COLOR_NOTA, false))
	_contenido.add_child(cabecera)
	_contenido.move_child(cabecera, 0)

	var pie := VBoxContainer.new()
	pie.add_theme_constant_override("separation", 2)
	pie.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var etiqueta := _texto("DÍA ACTUAL", 11, Gestor.COLOR_TEXTO_SUAVE, false)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_numero_actual = _texto(str(GameManager.current_sol), 18, Gestor.COLOR_HOY_TEXTO, true)
	_numero_actual.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_numero_actual.size_flags_horizontal = Control.SIZE_SHRINK_END
	fila.add_child(etiqueta)
	fila.add_child(_numero_actual)
	pie.add_child(fila)

	pie.add_child(_texto("LÍMITE / DÍA 60", 12, Gestor.COLOR_CORAL, true))
	var aviso := _texto("El cohete debe llegar ANTES de agotar la comida.", 11, Gestor.COLOR_NOTA, false)
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pie.add_child(aviso)
	_contenido.add_child(pie)

	if mostrar_botones_de_prueba:
		_crear_botones_prueba(_contenido)


func _conectar() -> void:
	var gestor = Gestor.obtener()
	if not gestor.eventos_actualizados.is_connected(_refrescar):
		gestor.eventos_actualizados.connect(_refrescar)
	if not gestor.tiempo_actualizado.is_connected(_al_mover_el_tiempo):
		gestor.tiempo_actualizado.connect(_al_mover_el_tiempo)
	if not Events.sol_advanced.is_connected(_al_mover_el_tiempo):
		Events.sol_advanced.connect(_al_mover_el_tiempo)


func _al_mover_el_tiempo(_dia: int) -> void:
	_refrescar()


func _crear_celdas() -> void:
	for hijo in get_children():
		remove_child(hijo)
		hijo.free()
	_celdas.clear()
	for dia in range(1, GameManager.MAX_SOLS + 1):
		var boton := Button.new()
		boton.name = "Dia%02d" % dia
		boton.focus_mode = Control.FOCUS_NONE
		boton.clip_text = true
		boton.custom_minimum_size = Vector2(22, 22)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		boton.alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton.pressed.connect(_al_elegir_dia.bind(dia))
		_celdas.append(boton)
		add_child(boton)


func _refrescar() -> void:
	if _numero_actual != null:
		_numero_actual.text = str(GameManager.current_sol)
	var gestor = Gestor.obtener()
	for indice in _celdas.size():
		_pintar_celda(_celdas[indice], indice + 1, gestor)


func _pintar_celda(boton: Button, dia: int, gestor) -> void:
	var sol: int = GameManager.current_sol
	var eventos: Array = gestor.eventos_del_dia(dia)
	var es_pasado := dia < sol
	var es_hoy := dia == sol
	var zona_critica := dia >= 51

	var fondo: Color = Gestor.COLOR_ZONA_CRITICA if zona_critica else Gestor.COLOR_CELDA
	var borde: Color = Gestor.COLOR_BORDE_CRITICA if zona_critica else Gestor.COLOR_BORDE_CELDA
	var grosor := 1
	var tinta: Color = Gestor.COLOR_TEXTO_CRITICA if zona_critica else Gestor.COLOR_TEXTO_SUAVE
	var negrita := false

	if not eventos.is_empty():
		var acento: Color = _acento(eventos)
		if es_pasado:
			borde = acento.darkened(0.55)
			tinta = Gestor.COLOR_TEXTO_PASADO
		else:
			borde = acento
			grosor = 2
			tinta = acento

	if es_pasado and eventos.is_empty():
		tinta = Gestor.COLOR_TEXTO_PASADO

	if es_hoy:
		borde = Gestor.COLOR_HOY
		grosor = 2
		tinta = Gestor.COLOR_HOY_TEXTO
		negrita = true

	var estilo := _estilo_celda(fondo, borde, grosor)
	var hover := estilo.duplicate() as StyleBoxFlat
	hover.bg_color = fondo.lightened(0.08)
	boton.add_theme_stylebox_override("normal", estilo)
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("pressed", hover)
	boton.add_theme_stylebox_override("focus", estilo)
	boton.add_theme_stylebox_override("disabled", estilo)
	boton.add_theme_font_override("font", Gestor.fuente(negrita))
	boton.add_theme_font_size_override("font_size", 10)
	boton.add_theme_color_override("font_color", tinta)
	boton.add_theme_color_override("font_hover_color", tinta)
	boton.add_theme_color_override("font_pressed_color", tinta)
	boton.text = "%02d" % dia
	boton.tooltip_text = gestor.resumen_dia(dia)


func _acento(eventos: Array) -> Color:
	var material := false
	var fabricacion := false
	var mantenimiento := false
	for evento in eventos:
		match str(evento["tipo"]):
			Gestor.TIPO_MANTENIMIENTO:
				mantenimiento = true
			Gestor.TIPO_FABRICACION:
				fabricacion = true
			Gestor.TIPO_MATERIAL:
				material = true
	if mantenimiento:
		return Gestor.COLOR_MANTENIMIENTO
	if fabricacion:
		return Gestor.COLOR_FABRICACION
	if material:
		return Gestor.COLOR_MATERIAL
	return Gestor.COLOR_OTRO


func _estilo_celda(fondo: Color, borde: Color, grosor: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(2)
	estilo.set_content_margin_all(0)
	estilo.anti_aliasing = false
	return estilo


func _texto(mensaje: String, tamano: int, color: Color, negrita: bool) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = mensaje
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_override("font", Gestor.fuente(negrita))
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta


func _al_elegir_dia(dia: int) -> void:
	var boton := _celdas[dia - 1]
	boton.tooltip_text = Gestor.obtener().resumen_dia(dia)


func saltar_al_siguiente_evento() -> void:
	var gestor = Gestor.obtener()
	var destino: int = gestor.dia_proximo_evento()
	if destino < 0:
		print("[Calendario] No hay un evento futuro.")
		return
	var sol: int = gestor.avanzar_hasta_proximo_evento()
	print("[Calendario] Saltó al sol %d (próximo evento: día %d)." % [sol, destino])


func _unhandled_input(evento: InputEvent) -> void:
	if not teclas_de_prueba or not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_F1:
			_avanzar_un_dia()
		KEY_F2:
			_registrar_prueba(3, "Aleación de titanio", Gestor.TIPO_MATERIAL, "Pedido de materiales")
		KEY_F3:
			_registrar_prueba(7, "Motor principal", Gestor.TIPO_FABRICACION, "Ensamblaje del motor")
		KEY_F4:
			_registrar_prueba(1, "Inspección de la base", Gestor.TIPO_MANTENIMIENTO, "Riesgo en el hangar")
		KEY_F6:
			saltar_al_siguiente_evento()
		KEY_F7:
			_cancelar_ultimo()
		KEY_F8:
			_agregar_ejemplos()
		_:
			return
	get_viewport().set_input_as_handled()


func _avanzar_un_dia() -> void:
	if GameManager.food_rations <= 0.0 or GameManager.current_phase == GameManager.MissionPhase.EVALUATION:
		print("[Calendario] La comida se agotó. El tiempo ya no avanza.")
		_refrescar()
		return
	GameManager.advance_sol()
	Gestor.obtener().notificar_refresco()
	print("[Calendario] Sol %d | raciones %.1f | próximo evento: %d" % [
		GameManager.current_sol,
		GameManager.food_rations,
		Gestor.obtener().dia_proximo_evento(),
	])


func _agregar_ejemplos() -> void:
	Gestor.obtener().depurar_agregar_ejemplos()
	print("[Calendario] Ejemplos cargados. Total de eventos: %d" % Gestor.obtener().cantidad())


func _cancelar_ultimo() -> void:
	var gestor = Gestor.obtener()
	var id := gestor.ultimo_id()
	if id == "" or not gestor.cancelar_ultimo():
		print("[Calendario] No hay eventos para cancelar.")
		return
	print("[Calendario] Cancelado %s." % id)


func _registrar_prueba(delta: int, titulo: String, tipo: String, descripcion: String) -> void:
	var dia := clampi(GameManager.current_sol + delta, 1, GameManager.MAX_SOLS)
	var id: String = Gestor.obtener().registrar_evento(dia, titulo, tipo, descripcion, {"debug": true})
	if id == "":
		print("[Calendario] No se pudo registrar '%s'." % titulo)
		return
	print("[Calendario] %s en el día %d (%s)." % [titulo, dia, id])


func _crear_botones_prueba(padre: Node) -> void:
	var caja := GridContainer.new()
	caja.name = "PruebasCalendario"
	caja.columns = 2
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("h_separation", 4)
	caja.add_theme_constant_override("v_separation", 4)
	padre.add_child(caja)
	_boton_prueba(caja, "BtnPruebaMasDia", "+1 día", _avanzar_un_dia)
	_boton_prueba(caja, "BtnPruebaSaltar", "Saltar evento", saltar_al_siguiente_evento)
	_boton_prueba(caja, "BtnPruebaEjemplos", "Ejemplos", _agregar_ejemplos)
	_boton_prueba(caja, "BtnPruebaCancelar", "Cancelar último", _cancelar_ultimo)


func _boton_prueba(caja: GridContainer, nombre: String, texto: String, callback: Callable) -> void:
	var boton := Button.new()
	boton.name = nombre
	boton.text = texto
	boton.focus_mode = Control.FOCUS_NONE
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.pressed.connect(callback)
	caja.add_child(boton)
