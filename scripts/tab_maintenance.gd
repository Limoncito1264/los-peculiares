extends Control
## res://scripts/tab_maintenance.gd
## Vista de Mantenimiento y Eventos Aleatorios. No guarda estado: lo consulta.

signal supply_purchase_requested(supply_id: String)

const Catalog = preload("res://data/shop_catalog.gd")
const Mock = preload("res://data/mock_state.gd")
const FaultCardScene := preload("res://scenes/components/fault_card.tscn")
const SupplyRowScene := preload("res://scenes/components/supply_row.tscn")

@onready var lbl_estado_turno: Label = %LblEstadoTurno
@onready var lista_fallas: Container = %ListaFallas
@onready var lista_suministros: Container = %ListaSuministros
@onready var lbl_mensaje: Label = %LblMensaje

var state                      # GameManager o MockState (duck typing)
var _supply_rows: Dictionary = {}


func _ready() -> void:
	state = Mock.resolve(self)
	_build_supplies()
	_connect_state()
	_refresh()


func _exit_tree() -> void:
	# La pestaña se destruye al cambiar de menú: desconectar del autoload.
	if state != null and state.has_signal("state_changed") \
			and state.is_connected("state_changed", _refresh):
		state.disconnect("state_changed", _refresh)
	var ev := get_node_or_null("/root/Events")
	if ev != null and ev.has_signal("sol_advanced") \
			and ev.is_connected("sol_advanced", _refresh):
		ev.disconnect("sol_advanced", _refresh)


func _connect_state() -> void:
	if state.has_signal("state_changed"):
		state.connect("state_changed", _refresh)
	var ev := get_node_or_null("/root/Events")
	if ev != null and ev.has_signal("sol_advanced"):
		ev.connect("sol_advanced", _refresh)


func _build_supplies() -> void:
	for def in Catalog.SUPPLIES:
		var row = SupplyRowScene.instantiate()
		lista_suministros.add_child(row)
		row.setup(def)
		row.purchase_requested.connect(_on_supply_purchase)
		_supply_rows[def["id"]] = row


## Parámetro opcional para aceptar señales de Events con 1 argumento.
func _refresh(_arg = null) -> void:
	var blocked: bool = state.is_blocked()
	var has_sig: bool = bool(state.signal_active)
	var workers: Dictionary = state.get_workers_info()

	# Estado de acción física en Marte
	lbl_estado_turno.text = str(state.get_estado_accion())
	lbl_estado_turno.theme_type_variation = &"LabelError" if blocked else &"LabelOk"

	# Fallas: se reconstruyen (son pocas) separadas por origen
	for c in lista_fallas.get_children():
		lista_fallas.remove_child(c)
		c.queue_free()

	var marte: Array = []
	var tierra: Array = []
	for f in state.get_faults():
		if str(f.get("tipo", "tierra")) == "marte":
			marte.append(f)
		else:
			tierra.append(f)

	_add_header("EVENTOS EN MARTE (emergencias: bloquean todo)")
	for f in marte:
		_add_card(f, false)

	_add_header("EVENTOS EN LA TIERRA · TRABAJADORES: %d libres / %d" % [workers["free"], workers["total"]])
	for f in tierra:
		var sin_trabajador: bool = int(workers["free"]) <= 0 and not bool(f.get("en_reparacion", false))
		_add_card(f, blocked or not has_sig or sin_trabajador)

	# Suministros: se actualizan in-place
	for id in _supply_rows:
		var reserva := int(state.supply_stock.get(id, 0))
		var en_camino := 0
		for p in state.pending_supplies:
			if p["id"] == id:
				en_camino += 1
		_supply_rows[id].update_state(reserva, en_camino, blocked or not has_sig)


func _add_header(texto: String) -> void:
	var lbl := Label.new()
	lbl.text = texto
	lbl.theme_type_variation = &"LabelEyebrow"
	lista_fallas.add_child(lbl)


func _add_card(f: Dictionary, locked: bool) -> void:
	var card = FaultCardScene.instantiate()
	lista_fallas.add_child(card)
	card.setup(f)
	card.set_locked(locked)
	card.repair_requested.connect(_on_repair)


func _on_repair(fault_id: String) -> void:
	var r = state.reparar_falla(fault_id)
	var ok := false
	var msg := ""
	if typeof(r) == TYPE_DICTIONARY:
		ok = bool(r.get("ok", false))
		msg = str(r.get("msg", ""))
	else:
		ok = bool(r)
		msg = "Falla reparada." if ok else "No se pudo reparar la falla."
	_set_msg(msg, "ok" if ok else "error")
	_refresh()


func _on_supply_purchase(supply_id: String) -> void:
	supply_purchase_requested.emit(supply_id)
	var res: Dictionary = state.buy_supply(supply_id)
	_set_msg(str(res.get("msg", "")), "ok" if res.get("ok", false) else "error")
	_refresh()


func _set_msg(text: String, kind: String) -> void:
	lbl_mensaje.text = text
	match kind:
		"ok": lbl_mensaje.theme_type_variation = &"LabelOk"
		"warn": lbl_mensaje.theme_type_variation = &"LabelWarn"
		_: lbl_mensaje.theme_type_variation = &"LabelError"
