extends Control
## Visor de la cámara del hangar: cúpula de la Tierra, torre de cristal y nave por etapas.
## Lo crea MonitorHangar. Si lo agregas a mano, asígnale este script para cargar PNG en el Inspector.

@export var textura_planeta: Texture2D
@export var textura_edificio: Texture2D
@export var texturas_nave_etapas: Array[Texture2D] = []

var piezas: int = 0
var en_linea: bool = true

var _tiempo: float = 0.0
var _estrellas: Array[Dictionary] = []
var _fuente_banner: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_sembrar_estrellas()


func establecer_estado(cantidad: int, senal_activa: bool) -> void:
	piezas = clampi(cantidad, 0, 4)
	en_linea = senal_activa
	queue_redraw()


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()


func _sembrar_estrellas() -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = 60214
	var paleta: Array[Color] = [Color("#F4F7FB"), Color("#9EC9FF"), Color("#F2D36B")]
	for _i in 42:
		_estrellas.append({
			"p": Vector2(azar.randf(), azar.randf()),
			"c": paleta[azar.randi() % paleta.size()],
			"s": 2 if azar.randf() > 0.84 else 1,
			"f": azar.randf() * TAU,
		})


func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return
	var tierra := _geometria_tierra()
	_dibujar_cielo(tierra)
	_dibujar_planeta(tierra)
	_dibujar_edificio(tierra)
	_dibujar_nave(tierra)
	_dibujar_escaneo(tierra)
	_dibujar_marcas()
	if piezas >= 4:
		_dibujar_lista()
	if not en_linea:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.08, 0.45), true)


func _geometria_tierra() -> Dictionary:
	var pico_y := size.y * 0.60
	var medio := size.x * 0.5
	var centro_y := (medio * medio + size.y * size.y - pico_y * pico_y) / (2.0 * (size.y - pico_y))
	return {
		"centro": Vector2(medio, centro_y),
		"radio": centro_y - pico_y,
		"pico_y": pico_y,
	}


func _dibujar_cielo(tierra: Dictionary) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#060911"), true)
	var limite: float = tierra["pico_y"]
	for estrella in _estrellas:
		var punto := Vector2(float(estrella["p"].x) * size.x, float(estrella["p"].y) * limite * 0.92)
		var pulso := 0.35 + 0.65 * absf(sin(_tiempo * 1.6 + float(estrella["f"])))
		var color: Color = estrella["c"]
		color.a = pulso
		var lado := float(estrella["s"])
		draw_rect(Rect2(punto, Vector2(lado, lado)), color, true)


func _dibujar_planeta(tierra: Dictionary) -> void:
	var centro: Vector2 = tierra["centro"]
	var radio: float = tierra["radio"]
	var pico: float = tierra["pico_y"]
	if textura_planeta != null:
		draw_texture_rect(textura_planeta, Rect2(0.0, pico - 6.0, size.x, size.y - pico + 6.0), false)
		return
	var borde := clampf(size.x * 0.018, 3.0, 7.0)
	draw_circle(centro, radio + borde, Color("#7DD3FC"))
	draw_circle(centro, radio, Color("#3B82F6"))
	draw_circle(centro + Vector2(0.0, -borde * 2.2), radio * 0.965, Color("#4A89DC"))
	_dibujar_continentes(centro, radio)


func _dibujar_continentes(centro: Vector2, radio: float) -> void:
	var america: Array[Vector2] = [
		Vector2(-0.58, -0.48), Vector2(-0.58, -0.72), Vector2(-0.40, -0.72),
		Vector2(-0.40, -0.82), Vector2(-0.22, -0.82), Vector2(-0.22, -0.64),
		Vector2(-0.14, -0.64), Vector2(-0.14, -0.52), Vector2(-0.32, -0.46),
		Vector2(-0.48, -0.46),
	]
	var america_sur: Array[Vector2] = [
		Vector2(-0.34, -0.42), Vector2(-0.20, -0.42), Vector2(-0.16, -0.24),
		Vector2(-0.26, -0.16), Vector2(-0.38, -0.28),
	]
	var eurafrica: Array[Vector2] = [
		Vector2(0.12, -0.78), Vector2(0.36, -0.78), Vector2(0.46, -0.66),
		Vector2(0.46, -0.48), Vector2(0.32, -0.34), Vector2(0.18, -0.26),
		Vector2(0.10, -0.46), Vector2(0.10, -0.66),
	]
	_continente(centro, radio, america, Color("#7AC943"))
	_continente(centro, radio, america_sur, Color("#8CC152"))
	_continente(centro, radio, eurafrica, Color("#7AC943"))
	_continente(centro, radio, _encoger(america, 0.62), Color("#8CC152"))
	_continente(centro, radio, _encoger(eurafrica, 0.55), Color("#8CC152"))


func _dibujar_edificio(tierra: Dictionary) -> void:
	var u := _unidad()
	var centro: Vector2 = tierra["centro"]
	var radio: float = tierra["radio"]
	var eje_x := size.x * 0.34
	var base_y := _altura_curva(eje_x, centro, radio)
	var antena_max := size.y * 0.07
	var disponible := base_y - 20.0 - antena_max
	var alto := minf(size.y * 0.40, maxf(disponible, 1.0))
	var techo := base_y - alto
	var ancho := clampf(alto * 0.48, size.x * 0.14, size.x * 0.22)
	var zona := Rect2(eje_x - ancho * 0.5, techo, ancho, alto)
	if textura_edificio != null:
		draw_texture_rect(textura_edificio, zona, false)
		return
	var metal := Color("#1E293B")
	var podio := Rect2(zona.position.x - 6.0 * u, zona.end.y - 10.0 * u, zona.size.x + 12.0 * u, 12.0 * u)
	draw_rect(podio, metal, true)
	draw_rect(zona, metal, true)
	var torre := Rect2(zona.position.x + zona.size.x * 0.18, zona.position.y, zona.size.x * 0.64, zona.size.y * 0.30)
	draw_rect(torre, metal, true)
	var cristal := zona.grow(-3.0 * u)
	draw_rect(cristal, Color("#2563EB"), true)
	draw_rect(Rect2(cristal.position.x, cristal.position.y, cristal.size.x * 0.28, cristal.size.y), Color("#38BDF8"), true)
	var cristal_torre := torre.grow(-2.5 * u)
	draw_rect(cristal_torre, Color("#2563EB"), true)
	_ventanas(cristal, 5, 3)
	_ventanas(cristal_torre, 2, 2)
	var antena_x := torre.position.x + torre.size.x * 0.5
	var baliza_h := 3.0 * u
	var antena_h := minf(antena_max, maxf(zona.position.y - 18.0 - baliza_h, 0.0))
	if antena_h > 2.0:
		draw_rect(Rect2(antena_x - u, zona.position.y - antena_h, maxf(2.0, 2.0 * u), antena_h), metal, true)
		var baliza := sin(_tiempo * 7.0) > 0.0
		draw_rect(Rect2(antena_x - 2.0 * u, zona.position.y - antena_h - baliza_h, 4.0 * u, baliza_h), Color("#E05A47") if baliza else Color("#3F1D24"), true)


func _dibujar_nave(tierra: Dictionary) -> void:
	var u := _unidad()
	var centro: Vector2 = tierra["centro"]
	var radio: float = tierra["radio"]
	var eje_x := size.x * 0.52
	var curva := _altura_curva(eje_x, centro, radio)
	var punta := maxf(20.0, curva - size.y * 0.40)
	var pad_h := maxf(5.0, size.y * 0.045)
	var plataforma := Rect2(eje_x - size.x * 0.17, curva - pad_h * 0.45, size.x * 0.34, pad_h)
	var vuelo := maxf(plataforma.position.y - punta, size.y * 0.28)
	var tanque_h := vuelo / 1.22
	var tanque_w := maxf(7.0, size.x * 0.062)
	var zona_nave := Rect2(eje_x - size.x * 0.16, punta, size.x * 0.32, plataforma.position.y - punta)
	_dibujar_plataforma(plataforma, u)
	if piezas > 0 and _textura_de_etapa(piezas - 1) != null:
		draw_texture_rect(_textura_de_etapa(piezas - 1), zona_nave, false)
		return
	if piezas <= 0:
		return
	var tanque := Rect2(eje_x - tanque_w * 0.5, plataforma.position.y - tanque_h, tanque_w, tanque_h)
	if piezas >= 2:
		var booster_w := tanque_w * 0.72
		var booster_h := tanque_h * 0.78
		_propulsor(Rect2(tanque.position.x - booster_w - 2.0 * u, tanque.position.y + tanque_h * 0.18, booster_w, booster_h), u)
		_propulsor(Rect2(tanque.end.x + 2.0 * u, tanque.position.y + tanque_h * 0.18, booster_w, booster_h), u)
	_tanque(tanque, u)
	_motores(tanque, u)
	if piezas >= 3:
		_orbitador(tanque, u)
	if piezas >= 4:
		_luces_y_vapor(tanque, u)


func _dibujar_plataforma(plataforma: Rect2, u: float) -> void:
	draw_rect(Rect2(plataforma.position.x + 8.0 * u, plataforma.end.y - 3.0 * u, plataforma.size.x - 16.0 * u, 5.0 * u), Color(0.05, 0.08, 0.12, 0.45), true)
	draw_rect(plataforma, Color("#1E293B"), true)
	draw_rect(Rect2(plataforma.position.x, plataforma.position.y, plataforma.size.x, 3.0 * u), Color("#334155"), true)
	draw_rect(Rect2(plataforma.position.x + plataforma.size.x * 0.38, plataforma.position.y + 3.0 * u, plataforma.size.x * 0.24, 2.0 * u), Color("#F2B84B"), true)


func _tanque(tanque: Rect2, u: float) -> void:
	draw_rect(tanque, Color("#E8EEF7"), true)
	draw_rect(Rect2(tanque.position.x, tanque.position.y, tanque.size.x * 0.28, tanque.size.y), Color("#CBD5E1"), true)
	draw_rect(Rect2(tanque.position.x, tanque.position.y + tanque.size.y * 0.42, tanque.size.x, 4.0 * u), Color("#F59E0B"), true)
	draw_rect(Rect2(tanque.position.x + 2.0 * u, tanque.position.y, tanque.size.x - 4.0 * u, 5.0 * u), Color("#F8FAFC"), true)


func _motores(tanque: Rect2, u: float) -> void:
	var y := tanque.end.y - 2.0 * u
	for desplazamiento in [-4.5, 0.0, 4.5]:
		_campana(tanque.position.x + tanque.size.x * 0.5 + desplazamiento * u, y, 7.0 * u, 8.0 * u, Color("#334155"))


func _propulsor(cuerpo: Rect2, u: float) -> void:
	draw_rect(cuerpo, Color("#F8FAFC"), true)
	draw_rect(Rect2(cuerpo.position.x, cuerpo.position.y, 3.0 * u, cuerpo.size.y), Color("#E2E8F0"), true)
	draw_rect(Rect2(cuerpo.position.x, cuerpo.position.y, cuerpo.size.x, 5.0 * u), Color("#94A3B8"), true)
	_campana(cuerpo.position.x + cuerpo.size.x * 0.5, cuerpo.end.y - u, cuerpo.size.x * 0.7, 7.0 * u, Color("#475569"))


func _orbitador(tanque: Rect2, u: float) -> void:
	var cuerpo := Rect2(tanque.end.x - tanque.size.x * 0.45, tanque.position.y - tanque.size.y * 0.06, tanque.size.x * 0.95, tanque.size.y * 0.9)
	var ala_izq := PackedVector2Array([
		cuerpo.position + Vector2(u, cuerpo.size.y * 0.42),
		cuerpo.position + Vector2(-cuerpo.size.x * 1.7, cuerpo.size.y * 0.78),
		cuerpo.position + Vector2(u, cuerpo.size.y * 0.70),
	])
	var ala_der := PackedVector2Array([
		cuerpo.position + Vector2(cuerpo.size.x - u, cuerpo.size.y * 0.42),
		cuerpo.position + Vector2(cuerpo.size.x * 1.7, cuerpo.size.y * 0.76),
		cuerpo.position + Vector2(cuerpo.size.x - u, cuerpo.size.y * 0.68),
	])
	draw_colored_polygon(ala_izq, Color("#F8FAFC"))
	draw_colored_polygon(ala_der, Color("#E2E8F0"))
	draw_rect(cuerpo, Color("#F8FAFC"), true)
	draw_rect(Rect2(cuerpo.position.x, cuerpo.position.y + cuerpo.size.y * 0.55, cuerpo.size.x, cuerpo.size.y * 0.45), Color("#E8EEF7"), true)
	var nariz_h := tanque.size.y * 0.18
	var nariz := PackedVector2Array([
		cuerpo.position + Vector2(0.0, nariz_h * 0.45),
		cuerpo.position + Vector2(cuerpo.size.x * 0.5, -nariz_h),
		cuerpo.position + Vector2(cuerpo.size.x, nariz_h * 0.45),
	])
	draw_colored_polygon(nariz, Color("#0F172A"))
	for indice in 3:
		draw_rect(Rect2(cuerpo.position.x + cuerpo.size.x * 0.22, cuerpo.position.y + nariz_h * 0.55 + indice * cuerpo.size.y * 0.07, cuerpo.size.x * 0.5, maxf(2.0, u * 2.2)), Color("#0EA5E9"), true)


func _luces_y_vapor(tanque: Rect2, u: float) -> void:
	var pulso := sin(_tiempo * 8.0) > 0.0
	var cuerpo_x := tanque.end.x - tanque.size.x * 0.45
	draw_rect(Rect2(cuerpo_x - tanque.size.x * 1.35, tanque.position.y + tanque.size.y * 0.62, 3.5 * u, 3.5 * u), Color("#E05A47") if pulso else Color("#3F1D24"), true)
	draw_rect(Rect2(cuerpo_x + tanque.size.x * 1.15, tanque.position.y + tanque.size.y * 0.58, 3.5 * u, 3.5 * u), Color("#4ADE80") if not pulso else Color("#14532D"), true)
	draw_rect(Rect2(cuerpo_x + tanque.size.x * 0.28, tanque.position.y - tanque.size.y * 0.2, 3.0 * u, 3.0 * u), Color("#F8FAFC") if sin(_tiempo * 5.0) > 0.15 else Color("#334155"), true)
	for indice in 5:
		var ciclo := fmod(_tiempo * 0.7 + float(indice) * 0.22, 1.0)
		var alfa := (1.0 - ciclo) * 0.38
		var origen := Vector2(tanque.position.x + tanque.size.x * 0.5 + sin(_tiempo * 2.0 + indice) * 4.0 * u, tanque.end.y + ciclo * 8.0 * u)
		draw_circle(origen, (2.2 + ciclo * 4.5) * u, Color(0.93, 0.95, 0.98, alfa))


func _dibujar_lista() -> void:
	var fuente := _fuente()
	var texto := "LISTA PARA LANZAMIENTO"
	var tamano := 9
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var x := (size.x - ancho) * 0.5
	var y := size.y - 8.0
	var alfa := 0.72 + 0.28 * absf(sin(_tiempo * 3.0))
	draw_rect(Rect2(x - 6.0, y - tamano - 3.0, ancho + 12.0, tamano + 8.0), Color(0.03, 0.06, 0.1, 0.78), true)
	draw_string(fuente, Vector2(x, y), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, Color("#4ADE80", alfa))


func _dibujar_escaneo(tierra: Dictionary) -> void:
	var limite: float = tierra["pico_y"]
	var techo := 18.0
	var recorrido := maxf(limite - techo, 8.0)
	var y := techo + fmod(_tiempo * 22.0, recorrido)
	draw_rect(Rect2(0.0, y, size.x, 7.0), Color(0.45, 0.85, 1.0, 0.05), true)
	draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.75, 0.95, 1.0, 0.22), 1.0)


func _dibujar_marcas() -> void:
	var color := Color("#F2B84B")
	var margen := 8.0
	var largo := 12.0
	var abajo := size.y - margen
	draw_line(Vector2(margen, abajo), Vector2(margen + largo, abajo), color, 1.5)
	draw_line(Vector2(margen, abajo), Vector2(margen, abajo - largo), color, 1.5)
	draw_line(Vector2(size.x - margen, abajo), Vector2(size.x - margen - largo, abajo), color, 1.5)
	draw_line(Vector2(size.x - margen, abajo), Vector2(size.x - margen, abajo - largo), color, 1.5)


func _ventanas(zona: Rect2, filas: int, columnas: int) -> void:
	if zona.size.x < 8.0 or zona.size.y < 8.0:
		return
	var hueco_x := zona.size.x / float(columnas)
	var hueco_y := zona.size.y / float(filas)
	for fila in filas:
		for columna in columnas:
			var encendida := _luz_encendida(fila * columnas + columna)
			var color := Color("#E0F2FE") if encendida else Color("#1E3A8A")
			draw_rect(Rect2(
				zona.position.x + columna * hueco_x + hueco_x * 0.22,
				zona.position.y + fila * hueco_y + hueco_y * 0.28,
				maxf(2.0, hueco_x * 0.42),
				maxf(2.0, hueco_y * 0.38)
			), color, true)


func _continente(centro: Vector2, radio: float, puntos: Array[Vector2], color: Color) -> void:
	var figura := PackedVector2Array()
	for punto in puntos:
		var vector := punto
		if vector.length() > 0.93:
			vector = vector.normalized() * 0.93
		figura.append(centro + vector * radio)
	if figura.size() >= 3:
		draw_colored_polygon(figura, color)


func _encoger(puntos: Array[Vector2], factor: float) -> Array[Vector2]:
	var promedio := Vector2.ZERO
	for punto in puntos:
		promedio += punto
	promedio /= float(puntos.size())
	var resultado: Array[Vector2] = []
	for punto in puntos:
		resultado.append(promedio + (punto - promedio) * factor)
	return resultado


func _altura_curva(x: float, centro: Vector2, radio: float) -> float:
	var delta := x - centro.x
	var interior := radio * radio - delta * delta
	if interior <= 1.0:
		return size.y - 8.0
	return centro.y - sqrt(interior)


func _campana(eje_x: float, y: float, ancho: float, alto: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(eje_x - ancho * 0.32, y),
		Vector2(eje_x + ancho * 0.32, y),
		Vector2(eje_x + ancho * 0.5, y + alto),
		Vector2(eje_x - ancho * 0.5, y + alto),
	]), color)


func _textura_de_etapa(indice: int) -> Texture2D:
	if indice < 0 or indice >= texturas_nave_etapas.size():
		return null
	return texturas_nave_etapas[indice]


func _unidad() -> float:
	return clampf(size.y / 165.0, 0.85, 1.35)


func _fuente() -> Font:
	if _fuente_banner == null:
		var fuente := SystemFont.new()
		fuente.font_names = PackedStringArray(["Segoe UI", "Arial"])
		fuente.font_weight = 700
		_fuente_banner = fuente
	return _fuente_banner


func _luz_encendida(indice: int) -> bool:
	if piezas >= 4:
		return true
	return sin(_tiempo * 2.4 + float(indice) * 0.85) > -0.15
