extends Control

# Cambia esta ruta cuando exista la escena del lore
const ESCENA_LORE := "res://scenes/Lore/Lore.tscn"

func _ready() -> void:
	%BotonJugar.pressed.connect(_on_jugar_pressed)
	%BotonJugar.grab_focus()
	var tween := create_tween().set_loops()
	tween.tween_property(%BotonJugar, "modulate:a", 0.55, 0.8)
	tween.tween_property(%BotonJugar, "modulate:a", 1.0, 0.8)

func _on_jugar_pressed() -> void:
	get_tree().change_scene_to_file(ESCENA_LORE)
