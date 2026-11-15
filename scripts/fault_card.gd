extends Control
## res://scripts/fault_card.gd
## Tarjeta de un evento aleatorio (Marte o Tierra). Solo muestra datos y emite una señal.

signal repair_requested(fault_id: String)

@onready var lbl_titulo: Label = %LblTitulo
@onready var lbl_desc: Label = %LblDesc
@onready var btn_reparar: Button = %BtnReparar

var fault_id: String = ""
var _data: Dictionary = {}
var _locked: bool = false


func _ready() -> void:
	btn_reparar.pressed.connect(func(): repair_requested.emit(fault_id))
	_apply()


## fault: {id, tipo, titulo, desc, prob, costo, dias_rep, activa, en_reparacion, restante}
func setup(fault: Dictionary) -> void:
	_data = fault
	fault_id = str(fault.get("id", ""))
	if is_node_ready():
		_apply()


## El tab decide si el botón debe estar bloqueado (sin señal, sin trabajadores, emergencia...).
func set_locked(locked: bool) -> void:
	_locked = locked
	if is_node_ready():
		_apply()


func _apply() -> void:
	if _data.is_empty():
		return
	var es_marte := str(_data.get("tipo", "tierra")) == "marte"
	var activa := bool(_data.get("activa", false))
	var reparando := bool(_data.get("en_reparacion", false))

	lbl_titulo.text = str(_data.get("titulo", "Falla"))
	if activa and es_marte:
		lbl_titulo.theme_type_variation = &"LabelError"
	elif reparando:
		lbl_titulo.theme_type_variation = &"LabelOk"
	elif activa:
		lbl_titulo.theme_type_variation = &"LabelWarn"
	else:
		lbl_titulo.theme_type_variation = &"LabelTitle"

	var estado := "Estable"
	if reparando:
		estado = "EN REPARACIÓN: %d d restantes" % int(_data.get("restante", 0))
	elif activa and es_marte:
		estado = "EMERGENCIA: bloquea todo · cuesta $%d y pierdes el día" % int(_data.get("costo", 0))
	elif activa:
		estado = "ACTIVA: reparar toma %d d" % int(_data.get("dias_rep", 0))

	lbl_desc.text = "%s\nProbabilidad diaria: %d%%  |  %s" % [
		_data.get("desc", ""),
		roundi(float(_data.get("prob", 0.0)) * 100.0),
		estado,
	]

	if reparando:
		btn_reparar.text = "EN REPARACIÓN"
		btn_reparar.disabled = true
	elif activa and es_marte:
		btn_reparar.text = "RESOLVER ($%d)" % int(_data.get("costo", 0))
		btn_reparar.disabled = _locked
	elif activa:
		btn_reparar.text = "ASIGNAR TRABAJADOR"
		btn_reparar.disabled = _locked
	else:
		btn_reparar.text = "REPARAR"
		btn_reparar.disabled = true
