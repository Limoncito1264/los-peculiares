@tool
extends Control

@export var celdas := 32           # diámetro del planeta, en "pixeles"
@export var tamano_pixel := 8      # tamaño de cada pixel en pantalla
@export var color_base := Color("1E6FD9")
@export var color_relieve := Color("3FAE5A")
@export var semilla := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actualizar()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_actualizar()  # para ver los cambios en vivo en el editor

func _actualizar() -> void:
	custom_minimum_size = Vector2.ONE * celdas * tamano_pixel
	queue_redraw()

func _draw() -> void:
	var ruido := FastNoiseLite.new()
	ruido.seed = semilla
	ruido.frequency = 0.08
	var c := celdas / 2.0
	for y in celdas:
		for x in celdas:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c)
			if d.length() > c:
				continue
			var col := color_relieve if ruido.get_noise_2d(x, y) > 0.0 else color_base
			if d.x + d.y > c * 0.6:  # sombra abajo a la derecha, da volumen
				col = col.darkened(0.35)
			draw_rect(Rect2(x * tamano_pixel, y * tamano_pixel, tamano_pixel, tamano_pixel), col)
