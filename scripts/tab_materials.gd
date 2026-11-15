extends Control
## res://scripts/tab_materials.gd
## Vista de pedidos de Materiales y Circuitos. No guarda estado persistente.

signal order_confirmed(items: Dictionary, total: int, deliver_sol: int)

const Catalog = preload("res://data/shop_catalog.gd")
const Mock = preload("res://data/mock_state.gd")
const ItemRowScene := preload("res://scenes/components/item_row.tscn")

@onready var lista_materiales: Container = %ListaMateriales
@onready var lista_circuitos: Container = %ListaCircuitos
@onready var lbl_resumen: Label = %LblResumenDetalle
@onready var lbl_entrega: Label = %LblEntrega
@onready var lbl_total: Label = %LblTotal
@onready var lbl_mensaje: Label = %LblMensaje
@onready var lbl_pedidos_hoy: Label = %LblPedidosHoy
@onready var btn_limpiar: Button = %BtnLimpiar
@onready var btn_confirmar: Button = %BtnConfirmar
@onready var lista_almacen: Container = %ListaAlmacen
@onready var lbl_transito: Label = %LblTransito

var state                       # GameManager o MockState (duck typing)
var _rows: Dictionary = {}      # id -> item_row
var _almacen_labels: Dictionary = {}  # id -> Label
var _panel_aviso: Control


func _ready() -> void:
	state = Mock.resolve(self)
	# PanelAvisoSenal no tiene Unique Name: se busca por nombre.
	_panel_aviso = find_child("PanelAvisoSenal", true, false) as Control
	_build_rows(Catalog.materials(), lista_materiales)
	_build_rows(Catalog.circuits(), lista_circuitos)
	_build_almacen()
	btn_limpiar.pressed.connect(_on_limpiar)
	btn_confirmar.pressed.connect(_on_confirmar)
	_connect_state()
	_refresh()


func _exit_tree() -> void:
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
	# Nombre de señal supuesto: ajústalo a tu Events.gd
	if ev != null and ev.has_signal("sol_advanced"):
		ev.connect("sol_advanced", _refresh)


func _build_rows(items: Array, parent: Container) -> void:
	for it in items:
		var row = ItemRowScene.instantiate()
		parent.add_child(row)
		row.setup(it)
		row.quantity_changed.connect(_on_quantity_changed)
		_rows[it["id"]] = row


func _build_almacen() -> void:
	for it in Catalog.all_items():
		var lbl := Label.new()
		lbl.theme_type_variation = &"LabelMuted"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lista_almacen.add_child(lbl)
		_almacen_labels[it["id"]] = lbl


# ---------- Lectura del estado ----------

func _collect_order() -> Dictionary:
	var order := {}
	for id in _rows:
		if _rows[id].cantidad > 0:
			order[id] = _rows[id].cantidad
	return order


func _refresh(_arg = null) -> void:
	var has_sig: bool = bool(state.signal_active)
	var orders_today: int = int(state.orders_today)

	if _panel_aviso != null:
		_panel_aviso.visible = not has_sig

	lbl_pedidos_hoy.text = "PEDIDOS HOY: %d / %d" % [orders_today, Catalog.MAX_ORDERS_PER_SOL]

	for id in _rows:
		_rows[id].set_locked(not has_sig)

	# Almacén
	for id in _almacen_labels:
		var it := Catalog.get_item(id)
		_almacen_labels[id].text = "%s: %d" % [it["nombre"], int(state.inventory.get(id, 0))]

	# En tránsito
	if state.pending_orders.is_empty():
		lbl_transito.text = "EN TRÁNSITO: ninguno"
	else:
		var lines: PackedStringArray = []
		for o in state.pending_orders:
			var parts: PackedStringArray = []
			for id in o["items"]:
				parts.append("%d× %s" % [o["items"][id], Catalog.get_item(id)["nombre"]])
			lines.append("Sol %d: %s" % [o["deliver_sol"], ", ".join(parts)])
		lbl_transito.text = "EN TRÁNSITO:\n" + "\n".join(lines)

	_update_summary()


func _update_summary() -> void:
	var order := _collect_order()
	var total := Catalog.order_total(order)
	lbl_total.text = "TOTAL: $%d" % total

	if order.is_empty():
		lbl_resumen.text = "Sin ítems seleccionados."
		lbl_entrega.text = "Entrega: —"
	else:
		var lines: PackedStringArray = []
		for id in order:
			var it := Catalog.get_item(id)
			lines.append("%d× %s — $%d" % [order[id], it["nombre"], int(it["precio"]) * int(order[id])])
		lbl_resumen.text = "\n".join(lines)
		var days := Catalog.order_delivery_days(order)
		lbl_entrega.text = "Entrega: Sol %d (en %d d)" % [int(state.current_sol) + days, days]

	btn_confirmar.disabled = order.is_empty() \
			or not bool(state.signal_active) \
			or int(state.orders_today) >= Catalog.MAX_ORDERS_PER_SOL


# ---------- Acciones ----------

func _on_quantity_changed(_id: String, _qty: int) -> void:
	_set_msg("", "ok")
	_update_summary()


func _on_limpiar() -> void:
	for id in _rows:
		_rows[id].reset()
	_set_msg("", "ok")
	_update_summary()


func _on_confirmar() -> void:
	var order := _collect_order()
	var res: Dictionary = state.place_order(order)
	if res.get("ok", false):
		_set_msg(str(res.get("msg", "Pedido confirmado.")), "ok")
		order_confirmed.emit(order, int(res.get("total", 0)), int(res.get("deliver_sol", 0)))
		for id in _rows:
			_rows[id].reset()
		_refresh()
	else:
		_set_msg(str(res.get("msg", "No se pudo completar el pedido.")), "error")


func _set_msg(text: String, kind: String) -> void:
	lbl_mensaje.text = text
	match kind:
		"ok": lbl_mensaje.theme_type_variation = &"LabelOk"
		"warn": lbl_mensaje.theme_type_variation = &"LabelWarn"
		_: lbl_mensaje.theme_type_variation = &"LabelError"
