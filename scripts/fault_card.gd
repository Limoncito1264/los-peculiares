extends Control
## res://scripts/fault_card.gd
## Tarjeta de una falla aleatoria. Solo muestra datos y emite una señal.

signal repair_requested(fault_id: String)

@onready var lbl_titulo: Label = %LblTitulo
@onready var lbl_desc: Label = %LblDesc
@onready var btn_reparar: Button = %BtnReparar

var fault_id: String = ""
var _data: Dictionary = {}


func _ready() -> void:
	btn_reparar.pressed.connect(func(): repair_requested.emit(fault_id))
	_apply()


## fault: {id, titulo, desc, prob (0..1), activa (bool)}
func setup(fault: Dictionary) -> void:
	_data = fault
	fault_id = str(fault.get("id", ""))
	if is_node_ready():
		_apply()


func set_locked(locked: bool) -> void:
	# Bloquea reparar sin señal (opcional; el tab lo llama).
	btn_reparar.disabled = locked or not bool(_data.get("activa", false))


func _apply() -> void:
	if _data.is_empty():
		return
	var activa := bool(_data.get("activa", false))
	lbl_titulo.text = str(_data.get("titulo", "Falla"))
	lbl_titulo.theme_type_variation = &"LabelError" if activa else &"LabelTitle"
	lbl_desc.text = "%s\nProbabilidad diaria: %d%%  |  %s" % [
		_data.get("desc", ""),
		roundi(float(_data.get("prob", 0.0)) * 100.0),
		"ACTIVA" if activa else "Estable",
	]
	btn_reparar.text = "REPARAR"
	btn_reparar.disabled = not activa
