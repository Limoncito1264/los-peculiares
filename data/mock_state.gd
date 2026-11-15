class_name MockState
extends RefCounted
## res://data/mock_state.gd
## Estado falso para probar cada escena sola con F6.
## Implementa EXACTAMENTE la misma API que debe tener GameManager.

const Catalog = preload("res://data/shop_catalog.gd")
const FaultSys = preload("res://data/fault_system.gd")

signal state_changed

const REQUIRED_PROPS := [
	"budget", "current_sol", "signal_active", "orders_today",
	"inventory", "pending_orders", "supply_stock", "pending_supplies",
]
const REQUIRED_METHODS := [
	"place_order", "buy_supply", "get_faults", "reparar_falla",
	"get_workers_info", "is_blocked", "get_blocking_event",
]

var budget: int = 5000
var current_sol: int = 1
var signal_active: bool = true   # (no usar "has_signal": choca con Object.has_signal())
var orders_today: int = 0
var inventory: Dictionary = {}        # id -> cantidad en almacén
var pending_orders: Array = []        # [{items:{id:qty}, deliver_sol:int}]
var supply_stock: Dictionary = {}     # id -> reserva actual
var pending_supplies: Array = []      # [{id:String, deliver_sol:int}]
var calendar_events: Array = []       # [{sol:int, texto:String}]

var _fault_sys := FaultSys.new()


func _init() -> void:
	for it in Catalog.all_items():
		inventory[it["id"]] = 0
	for s in Catalog.SUPPLIES:
		supply_stock[s["id"]] = 0
	# Para ver algo al probar: una falla terrestre ya activa
	_fault_sys.force_activate("t_software")


## Devuelve GameManager si existe y cumple la API; si no, un MockState local.
static func resolve(from: Node):
	var gm := from.get_node_or_null("/root/GameManager")
	if gm != null:
		var ok := true
		for p in REQUIRED_PROPS:
			if not (p in gm):
				ok = false
		for m in REQUIRED_METHODS:
			if not gm.has_method(m):
				ok = false
		if ok:
			return gm
		push_warning("GameManager no cumple la API requerida; usando MockState.")
	return MockState.new()


# ---------- Eventos aleatorios ----------

func is_blocked() -> bool:
	return _fault_sys.has_mars_event()


func get_blocking_event() -> Dictionary:
	return _fault_sys.get_blocking_event()


func _blocked_msg() -> String:
	var e := _fault_sys.get_blocking_event()
	return "Emergencia en Marte (%s): resuélvela primero." % str(e.get("titulo", ""))


func get_estado_accion() -> String:
	var e := _fault_sys.get_blocking_event()
	if e.is_empty():
		return "Sin acción física en curso en Marte."
	return "EMERGENCIA EN MARTE: %s. Todo lo demás está bloqueado hasta resolverla." % e["titulo"]


func get_faults() -> Array:
	return _fault_sys.get_faults()


func get_workers_info() -> Dictionary:
	return _fault_sys.workers_info()


func reparar_falla(id: String) -> Dictionary:
	var f := _fault_sys.find_fault(id)
	if f.is_empty():
		return {"ok": false, "msg": "Falla desconocida."}

	if f["tipo"] == "marte":
		if not f["activa"]:
			return {"ok": false, "msg": "Ese evento ya no está activo."}
		var costo := int(f["costo"])
		if budget < costo:
			return {"ok": false, "msg": "No tienes dinero suficiente"}
		budget -= costo
		_fault_sys.resolve_mars(id)
		advance_sol()   # día perdido
		return {"ok": true, "msg": "Emergencia resuelta (-$%d). Perdiste el día: ahora es el Sol %d." % [costo, current_sol]}

	if is_blocked():
		return {"ok": false, "msg": _blocked_msg()}
	if not signal_active:
		return {"ok": false, "msg": "Sin señal: no puedes dar órdenes a la Tierra."}
	var res := _fault_sys.start_earth_repair(id)
	state_changed.emit()
	return res


## Solo para pruebas: p. ej. state.forzar_evento("m_oxigeno")
func forzar_evento(id: String) -> void:
	_fault_sys.force_activate(id)
	state_changed.emit()


# ---------- Tienda ----------

## items: {id: qty}. Devuelve {ok:bool, msg:String, total:int, deliver_sol:int}
func place_order(items: Dictionary) -> Dictionary:
	if is_blocked():
		return {"ok": false, "msg": _blocked_msg()}
	if not signal_active:
		return {"ok": false, "msg": "Sin señal: no puedes hacer pedidos."}
	if orders_today >= Catalog.MAX_ORDERS_PER_SOL:
		return {"ok": false, "msg": "Límite de pedidos por Sol alcanzado."}
	var total := Catalog.order_total(items)
	if total <= 0:
		return {"ok": false, "msg": "El pedido está vacío."}
	if budget < total:
		return {"ok": false, "msg": "No tienes dinero suficiente"}
	budget -= total
	orders_today += 1
	var deliver := current_sol + Catalog.order_delivery_days(items)
	var clean := {}
	for id in items:
		if int(items[id]) > 0:
			clean[id] = int(items[id])
	pending_orders.append({"items": clean, "deliver_sol": deliver})
	calendar_events.append({"sol": deliver, "texto": "Llega pedido ($%d)" % total})
	state_changed.emit()
	return {"ok": true, "msg": "Pedido confirmado. Llega en el Sol %d." % deliver,
			"total": total, "deliver_sol": deliver}


func get_supply_in_transit(id: String) -> int:
	var n := 0
	for p in pending_supplies:
		if p["id"] == id:
			n += 1
	return n


func buy_supply(id: String) -> Dictionary:
	if is_blocked():
		return {"ok": false, "msg": _blocked_msg()}
	if not signal_active:
		return {"ok": false, "msg": "Sin señal: no puedes comprar suministros."}
	var s := Catalog.get_supply(id)
	if s.is_empty():
		return {"ok": false, "msg": "Suministro desconocido."}
	if int(supply_stock.get(id, 0)) + get_supply_in_transit(id) >= int(s["max"]):
		return {"ok": false, "msg": "Ya tienes el máximo de %s." % s["nombre"]}
	if budget < int(s["costo"]):
		return {"ok": false, "msg": "No tienes dinero suficiente"}
	budget -= int(s["costo"])
	var deliver := current_sol + int(s["dias"])
	pending_supplies.append({"id": id, "deliver_sol": deliver})
	calendar_events.append({"sol": deliver, "texto": "Llega %s" % s["nombre"]})
	state_changed.emit()
	return {"ok": true, "msg": "%s en camino (Sol %d)." % [s["nombre"], deliver]}


## Solo para pruebas en aislado.
func advance_sol() -> void:
	current_sol += 1
	orders_today = 0
	_fault_sys.tick_day(current_sol)
	var keep_orders: Array = []
	for o in pending_orders:
		if int(o["deliver_sol"]) <= current_sol:
			for id in o["items"]:
				inventory[id] = int(inventory.get(id, 0)) + int(o["items"][id])
		else:
			keep_orders.append(o)
	pending_orders = keep_orders
	var keep_sup: Array = []
	for p in pending_supplies:
		if int(p["deliver_sol"]) <= current_sol:
			supply_stock[p["id"]] = int(supply_stock.get(p["id"], 0)) + 1
		else:
			keep_sup.append(p)
	pending_supplies = keep_sup
	state_changed.emit()
