extends Control

# Confirma con tus compañeros cuál es la escena del juego
const ESCENA_JUEGO := "res://scenes/cockpit_main.tscn"
const SEG_POR_LETRA := 0.018
const PAUSA_SALTO_LINEA := 0.4

var paginas: PackedStringArray
var indice := 0
var escribiendo := false
var saltar_pagina := false

func _ready() -> void:
	paginas = %Texto.text.split("---")
	for i in paginas.size():
		paginas[i] = paginas[i].strip_edges()
	%BotonContinuar.pressed.connect(_on_continuar)
	%BotonSaltar.pressed.connect(_ir_al_juego)
	_mostrar_pagina()

func _mostrar_pagina() -> void:
	escribiendo = true
	saltar_pagina = false
	%BotonContinuar.disabled = true
	%BotonContinuar.modulate.a = 0.0   # oculto mientras se escribe
	%BotonContinuar.text = "COMENZAR MISIÓN >>" if indice == paginas.size() - 1 else "CONTINUAR >>"
	%Pagina.text = "%02d / %02d" % [indice + 1, paginas.size()]
	%Texto.text = paginas[indice]

	var texto: String = %Texto.get_parsed_text()
	%Texto.visible_characters = 0
	for i in texto.length():
		if saltar_pagina:
			break
		%Texto.visible_characters = i + 1
		var letra := texto[i]
		# Suena cada 2 letras, y no en espacios ni saltos de línea
		if letra != " " and letra != "\n" and i % 2 == 0:
			$SonidoTecla.pitch_scale = randf_range(0.9, 1.1)
			$SonidoTecla.play()
		var espera := PAUSA_SALTO_LINEA if letra == "\n" else SEG_POR_LETRA
		await get_tree().create_timer(espera).timeout

	%Texto.visible_characters = -1
	escribiendo = false
	%BotonContinuar.disabled = false
	%BotonContinuar.modulate.a = 1.0
	%BotonContinuar.grab_focus()

func _input(event: InputEvent) -> void:
	# Clic o Enter mientras se escribe: muestra toda la página de golpe
	if escribiendo and (event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed)):
		saltar_pagina = true

func _on_continuar() -> void:
	if indice < paginas.size() - 1:
		indice += 1
		_mostrar_pagina()
	else:
		_ir_al_juego()

func _ir_al_juego() -> void:
	get_tree().change_scene_to_file(ESCENA_JUEGO)
