extends TextureRect
## Fondo estrellado de toda la cabina.
## Adjuntar a un TextureRect hijo directo de CockpitMain, llamado FondoEspacio.

const RUTA_IMAGEN := "res://assets/fondo_espacio.png"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	z_index = -10
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ResourceLoader.exists(RUTA_IMAGEN):
		texture = load(RUTA_IMAGEN)
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		stretch_mode = TextureRect.STRETCH_TILE
	else:
		texture = _generar_cielo()
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	call_deferred("_enviar_al_fondo")


func _enviar_al_fondo() -> void:
	var padre := get_parent()
	if padre == null:
		return
	if padre is Container:
		push_warning("FondoEspacio tiene que ser hijo directo de CockpitMain. Un contenedor lo aplasta y tapa las estrellas.")
		return
	padre.move_child(self, 0)


func _generar_cielo() -> Texture2D:
	var ancho := 640
	var alto := 360
	var imagen := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	imagen.fill(Color("#060911"))
	var azar := RandomNumberGenerator.new()
	azar.seed = 20261114
	var paleta: Array[Color] = [
		Color("#F4F7FB"),
		Color("#9EC9FF"),
		Color("#F2D36B"),
		Color("#D6E4F0"),
	]
	for _i in 460:
		var x := azar.randi_range(0, ancho - 1)
		var y := azar.randi_range(0, alto - 1)
		var color := paleta[azar.randi() % paleta.size()]
		color.a = azar.randf_range(0.4, 1.0)
		var tamano := 2 if azar.randf() > 0.88 else 1
		for dy in tamano:
			for dx in tamano:
				imagen.set_pixel(mini(x + dx, ancho - 1), mini(y + dy, alto - 1), color)
	for _i in 90:
		var x := azar.randi_range(0, ancho - 1)
		var y := azar.randi_range(int(alto * 0.3), int(alto * 0.72))
		imagen.set_pixel(x, y, Color(0.28, 0.45, 0.75, 0.22))
	return ImageTexture.create_from_image(imagen)
