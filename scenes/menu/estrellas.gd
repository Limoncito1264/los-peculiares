extends Control

@export var cantidad := 120
var estrellas: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in cantidad:
		estrellas.append({
			"pos": Vector2(rng.randi_range(0, 1920), rng.randi_range(0, 1080)).snapped(Vector2(4, 4)),
			"tam": [4, 4, 4, 8][rng.randi_range(0, 3)],
			"fase": rng.randf() * TAU,
		})

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for e in estrellas:
		var brillo := 0.5 + 0.5 * sin(t * 2.0 + e.fase)
		var col := Color("FFF1B8", lerp(0.35, 1.0, brillo))
		draw_rect(Rect2(e.pos, Vector2(e.tam, e.tam)), col)
