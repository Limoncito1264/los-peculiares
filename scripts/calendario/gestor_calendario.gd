class_name GestorCalendario
extends RefCounted
## Cola de eventos del calendario (soles 1 a 60).
##
## No es un Autoload: así no hace falta tocar project.godot ni Events.gd.
## Otras pantallas lo usan así:
## [codeblock]
## var calendario := GestorCalendario.obtener()
## calendario.registrar_evento(
##     GameManager.current_sol + 4,
##     "Llegada de Aleación de Titanio",
##     GestorCalendario.TIPO_MATERIAL,
##     "Pedido en camino",
##     {"pedido_id": 12}
## )
## calendario.cancelar_por_dato("pedido_id", 12)
## [/codeblock]
## El día que se registra es el día en que el evento ocurre
## (llegada del pedido o fin de la fabricación), no el día en que empieza.

signal eventos_actualizados
## Se emite después de un salto de tiempo o de un refresco manual.
signal tiempo_actualizado(dia: int)

const TIPO_MATERIAL := "material"
const TIPO_FABRICACION := "fabricacion"
const TIPO_MANTENIMIENTO := "mantenimiento"
const TIPO_OTRO := "otro"

const COLOR_CAJA := Color("#0B101B")
const COLOR_BORDE_CAJA := Color("#1E2D42")
const COLOR_TARJETA := Color("#0E1522")
const COLOR_BORDE_TARJETA := Color("#22324A")
const COLOR_TEXTO := Color("#F0F4F8")
const COLOR_TEXTO_SUAVE := Color("#7A8BA3")
const COLOR_NOTA := Color("#6C7E96")
const COLOR_ORO := Color("#F2B84B")
const COLOR_CORAL := Color("#E05A47")
const COLOR_CELDA := Color("#0E1522")
const COLOR_BORDE_CELDA := Color("#1D2B40")
const COLOR_ZONA_CRITICA := Color("#241416")
const COLOR_BORDE_CRITICA := Color("#6E352C")
const COLOR_TEXTO_CRITICA := Color("#D47455")
const COLOR_TEXTO_PASADO := Color("#3B4859")
const COLOR_HOY := Color("#F2B84B")
const COLOR_HOY_TEXTO := Color("#FFFFFF")

const COLOR_MATERIAL := Color("#38BDF8")
const COLOR_FABRICACION := Color("#F59E0B")
const COLOR_MANTENIMIENTO := Color("#EF4444")
const COLOR_OTRO := Color("#94A3B8")
const COLOR_MIXTO := Color("#F2B84B")
const COLOR_VACIO := Color("#0E1522")

static var _fuente_regular: Font
static var _fuente_negrita: Font

static var _instancia

var _eventos: Array[Dictionary] = []
var _contador: int = 0
var _ultimo_id: String = ""
var _silencio: bool = false


static func obtener() -> GestorCalendario:
	if _instancia != null and is_instance_valid(_instancia):
		return _instancia
	_instancia = GestorCalendario.new()
	return _instancia


static func fuente(negrita: bool = false) -> Font:
	if _fuente_regular == null:
		var regular := SystemFont.new()
		regular.font_names = PackedStringArray(["Segoe UI", "Arial"])
		regular.font_weight = 400
		var gruesa := SystemFont.new()
		gruesa.font_names = PackedStringArray(["Segoe UI", "Arial"])
		gruesa.font_weight = 700
		_fuente_regular = regular
		_fuente_negrita = gruesa
	return _fuente_negrita if negrita else _fuente_regular


static func estilo_panel() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_CAJA
	estilo.border_color = COLOR_BORDE_CAJA
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(12)
	estilo.anti_aliasing = false
	return estilo


static func color_de_tipo(tipo: String) -> Color:
	match tipo:
		TIPO_MATERIAL:
			return COLOR_MATERIAL
		TIPO_FABRICACION:
			return COLOR_FABRICACION
		TIPO_MANTENIMIENTO:
			return COLOR_MANTENIMIENTO
		TIPO_OTRO:
			return COLOR_OTRO
		_:
			return COLOR_MIXTO


static func etiqueta_tipo(tipo: String) -> String:
	match tipo:
		TIPO_MATERIAL:
			return "Llegada"
		TIPO_FABRICACION:
			return "Fabricación"
		TIPO_MANTENIMIENTO:
			return "Emergencia"
		_:
			return "Evento"


## Registra un evento. Devuelve su id, o "" si el día o el título no sirven.
func registrar_evento(
	dia: int,
	titulo: String,
	tipo: String = TIPO_OTRO,
	descripcion: String = "",
	datos: Dictionary = {}
) -> String:
	if dia < 1 or dia > GameManager.MAX_SOLS:
		push_warning("GestorCalendario: el día %d está fuera de 1..%d." % [dia, GameManager.MAX_SOLS])
		return ""
	titulo = titulo.strip_edges()
	if titulo.is_empty():
		push_warning("GestorCalendario: el evento necesita un título.")
		return ""

	_contador += 1
	var id := "evt-%04d" % _contador
	_eventos.append({
		"id": id,
		"dia": dia,
		"titulo": titulo,
		"tipo": _normalizar_tipo(tipo),
		"descripcion": descripcion.strip_edges(),
		"datos": datos.duplicate(true),
	})
	_ultimo_id = id
	_emitir_eventos()
	return id


## Quita un evento por el id que devolvió registrar_evento.
func cancelar_evento(id: String) -> bool:
	for i in _eventos.size():
		if str(_eventos[i]["id"]) != id:
			continue
		_eventos.remove_at(i)
		_sincronizar_ultimo_id()
		_emitir_eventos()
		return true
	return false


## Quita todos los eventos cuyo diccionario datos tenga clave == valor.
## Sirve para cancelar un pedido sin guardar el id del calendario.
func cancelar_por_dato(clave: String, valor) -> int:
	var borrados := 0
	for i in range(_eventos.size() - 1, -1, -1):
		var datos := _datos_de(_eventos[i])
		if datos.has(clave) and datos[clave] == valor:
			_eventos.remove_at(i)
			borrados += 1
	if borrados > 0:
		_sincronizar_ultimo_id()
		_emitir_eventos()
	return borrados


func cancelar_ultimo() -> bool:
	if _ultimo_id == "":
		return false
	return cancelar_evento(_ultimo_id)


func reiniciar() -> void:
	_eventos.clear()
	_contador = 0
	_ultimo_id = ""
	_emitir_eventos()


func cantidad() -> int:
	return _eventos.size()


func ultimo_id() -> String:
	return _ultimo_id


func eventos_del_dia(dia: int) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for evento in _eventos:
		if int(evento["dia"]) == dia:
			resultado.append(evento.duplicate(true))
	resultado.sort_custom(_ordenar_eventos)
	return resultado


## Eventos de hoy y de los soles que aún no llegan, del más próximo al más lejano.
func eventos_pendientes() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for evento in _eventos:
		if int(evento["dia"]) >= GameManager.current_sol:
			resultado.append(evento.duplicate(true))
	resultado.sort_custom(_ordenar_eventos)
	return resultado


## Día del próximo evento estrictamente posterior a hoy.
## desde_dia < 0 usa el sol actual. Devuelve -1 si no hay ninguno.
func dia_proximo_evento(desde_dia: int = -1) -> int:
	var origen := GameManager.current_sol if desde_dia < 0 else desde_dia
	var mejor := -1
	for evento in _eventos:
		var dia := int(evento["dia"])
		if dia <= origen:
			continue
		if mejor < 0 or dia < mejor:
			mejor = dia
	return mejor


## Avanza con GameManager.advance_sol() hasta el día del próximo evento.
## Devuelve el sol alcanzado, o -1 si no había un evento futuro
## o si la comida ya se agotó.
func avanzar_hasta_proximo_evento() -> int:
	var destino := dia_proximo_evento()
	if destino < 0:
		return -1
	if GameManager.food_rations <= 0.0 or GameManager.current_phase == GameManager.MissionPhase.EVALUATION:
		return -1
	var guardia := 0
	while GameManager.current_sol < destino and guardia < GameManager.MAX_SOLS:
		guardia += 1
		var antes := GameManager.current_sol
		GameManager.advance_sol()
		if GameManager.current_sol <= antes:
			break
		if GameManager.food_rations <= 0.0:
			break
		if GameManager.current_phase == GameManager.MissionPhase.EVALUATION:
			break
	tiempo_actualizado.emit(GameManager.current_sol)
	return GameManager.current_sol


func notificar_refresco() -> void:
	tiempo_actualizado.emit(GameManager.current_sol)


func texto_espera(dia: int) -> String:
	var falta := dia - GameManager.current_sol
	if falta == 0:
		return "Hoy"
	if falta == 1:
		return "En 1 día"
	if falta > 1:
		return "En %d días" % falta
	if falta == -1:
		return "Hace 1 día"
	return "Hace %d días" % (-falta)


func resumen_dia(dia: int) -> String:
	var eventos := eventos_del_dia(dia)
	var encabezado := "Día %d · %s" % [dia, texto_espera(dia)]
	if eventos.size() == 1:
		encabezado += " · 1 evento"
	elif eventos.size() > 1:
		encabezado += " · %d eventos" % eventos.size()
	if dia == GameManager.MAX_SOLS:
		encabezado += "\nLímite crítico: se acaba la ventana de comida."
	if eventos.is_empty():
		return encabezado + "\nSin eventos programados"
	var lineas: PackedStringArray = [encabezado]
	for evento in eventos:
		lineas.append("• %s (%s)" % [evento["titulo"], etiqueta_tipo(str(evento["tipo"]))])
		var descripcion := str(evento.get("descripcion", ""))
		if descripcion != "":
			lineas.append("  %s" % descripcion)
	return "\n".join(lineas)


func color_del_dia(dia: int) -> Color:
	var tipos := {}
	for evento in _eventos:
		if int(evento["dia"]) != dia:
			continue
		tipos[str(evento["tipo"])] = true
	if tipos.is_empty():
		return COLOR_VACIO
	if tipos.size() > 1:
		return COLOR_MIXTO
	return color_de_tipo(str(tipos.keys()[0]))


## Inserta tres eventos de prueba relativos al sol actual. Vuelve a llamarlo para reemplazarlos.
func depurar_agregar_ejemplos() -> void:
	_silencio = true
	cancelar_por_dato("debug", true)
	var base := GameManager.current_sol
	registrar_evento(
		mini(base + 3, GameManager.MAX_SOLS),
		"Aleación de titanio",
		TIPO_MATERIAL,
		"Pedido de la tienda de materiales",
		{"debug": true}
	)
	registrar_evento(
		mini(base + 7, GameManager.MAX_SOLS),
		"Motor principal",
		TIPO_FABRICACION,
		"El personal termina el ensamblaje",
		{"debug": true}
	)
	registrar_evento(
		mini(base + 1, GameManager.MAX_SOLS),
		"Inspección de la base",
		TIPO_MANTENIMIENTO,
		"Riesgo de incendio en el hangar",
		{"debug": true}
	)
	_silencio = false
	_emitir_eventos()


func _normalizar_tipo(tipo: String) -> String:
	match tipo.strip_edges().to_lower():
		TIPO_MATERIAL, "materiales", "pedido", "llegada":
			return TIPO_MATERIAL
		TIPO_FABRICACION, "fabricación", "ensamblaje", "construccion", "construcción":
			return TIPO_FABRICACION
		TIPO_MANTENIMIENTO, "emergencia", "alerta", "riesgo":
			return TIPO_MANTENIMIENTO
		TIPO_OTRO, "":
			return TIPO_OTRO
		_:
			push_warning("GestorCalendario: tipo '%s' desconocido. Se usará '%s'." % [tipo, TIPO_OTRO])
			return TIPO_OTRO


func _datos_de(evento: Dictionary) -> Dictionary:
	if evento.has("datos") and evento["datos"] is Dictionary:
		return evento["datos"]
	return {}


func _sincronizar_ultimo_id() -> void:
	if _ultimo_id != "":
		for evento in _eventos:
			if str(evento["id"]) == _ultimo_id:
				return
	if _eventos.is_empty():
		_ultimo_id = ""
	else:
		_ultimo_id = str((_eventos.back() as Dictionary)["id"])


func _ordenar_eventos(a: Dictionary, b: Dictionary) -> bool:
	if int(a["dia"]) == int(b["dia"]):
		return str(a["id"]) < str(b["id"])
	return int(a["dia"]) < int(b["dia"])


func _emitir_eventos() -> void:
	if _silencio:
		return
	eventos_actualizados.emit()
