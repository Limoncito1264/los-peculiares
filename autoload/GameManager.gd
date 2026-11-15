extends Node

# Carga directa (no dependen del caché de class_name del editor)
const Catalog = preload("res://data/shop_catalog.gd")
const FaultSys = preload("res://data/fault_system.gd")

signal state_changed   # las vistas (tabs) se refrescan con esta señal

enum MissionPhase { DESIGN, MANAGEMENT, SIMULATION, EVALUATION }
var current_phase: MissionPhase = MissionPhase.DESIGN

# --- Supervivencia en Marte y Tiempo Límite ---
const MAX_SOLS: int = 60
var current_sol: int = 1
var food_rations: float = 60.0        # Suministros para 60 días
var signal_active: bool = true        # Estado de comunicación Tierra-Marte (antes "has_signal")
var blackout_days_left: int = 0

# --- Administración de Recursos y Subordinados ---
var budget: int = 1000                # Dinero disponible
var staff_count: int = 10             # Personal asignado en la Tierra
var crew_efficiency: float = 1.0      # Afectado por tus órdenes o falta de señal
var build_progress: float = 0.0       # 0.0 a 100.0% de construcción de la nave

# --- Métricas de Ingeniería (Trade-offs) ---
var equipped_parts: Array[SpacecraftPart] = []
var total_mass: float = 1000.0        # Masa base de la cápsula
var net_power: float = 0.0            # Balance energético
var science_score: int = 0            # Instrumentos científicos equipados
var launch_capacity: float = 3000.0   # Masa máxima que soporta el vehículo elegido
var orbital_alignment: float = 100.0  # Se degrada si te pasas de la ventana de 60 días

# --- Tienda (materiales, circuitos, suministros) ---
var orders_today: int = 0
var inventory: Dictionary = {}        # id -> cantidad en almacén
var pending_orders: Array = []        # [{items:{id:qty}, deliver_sol:int}]
var supply_stock: Dictionary = {}     # id -> reserva
var pending_supplies: Array = []      # [{id, deliver_sol}]

# --- Eventos aleatorios (Marte / Tierra + trabajadores) ---
var _fault_sys := FaultSys.new()


func _ready() -> void:
	_init_shop_state()


func _init_shop_state() -> void:
	for it in Catalog.all_items():
		inventory[it["id"]] = int(inventory.get(it["id"], 0))
	for s in Catalog.SUPPLIES:
		supply_stock[s["id"]] = int(supply_stock.get(s["id"], 0))


# --- Fase 1: Equipar piezas y calcular trade-offs ---
func equip_part(part: SpacecraftPart) -> bool:
	if budget < part.budget_cost:
		return false

	budget -= part.budget_cost
	equipped_parts.append(part)
	recalculate_engineering_stats()
	Events.resources_updated.emit()
	state_changed.emit()
	return true

func recalculate_engineering_stats() -> void:
	total_mass = 1000.0
	net_power = 0.0
	science_score = 0
	for part in equipped_parts:
		total_mass += part.mass_kg
		net_power += part.power_balance
		science_score += part.science_value

# --- Fase 2: Avanzar un Sol en Marte ---
func advance_sol(ration_multiplier: float = 1.0, work_speed: float = 1.0) -> void:
	current_sol += 1
	orders_today = 0          # reinicia el límite diario de pedidos
	_deliver_pending()        # entrega pedidos y suministros vencidos
	_tick_faults()            # avanza reparaciones y sortea eventos nuevos
	food_rations -= 1.0 * ration_multiplier

	# Verificar derrota por falta de comida
	if food_rations <= 0.0:
		state_changed.emit()
		change_phase(MissionPhase.EVALUATION)
		return

	# Gestionar días sin señal
	if blackout_days_left > 0:
		blackout_days_left -= 1
		if blackout_days_left == 0:
			signal_active = true
			Events.signal_status_changed.emit(true)

	# Avance de tus subordinados en la Tierra
	var daily_cost := int(staff_count * 5 * work_speed)
	if budget >= daily_cost:
		budget -= daily_cost
		# Sin señal, los subordinados trabajan con menor eficiencia por falta de supervisión
		var actual_efficiency := crew_efficiency if signal_active else crew_efficiency * 0.4
		build_progress += (staff_count * 0.25) * work_speed * actual_efficiency
		build_progress = clamp(build_progress, 0.0, 100.0)

	# Penalización por restricciones orbitales si se pasan los 60 días
	if current_sol > MAX_SOLS:
		orbital_alignment -= 15.0

	Events.sol_advanced.emit(current_sol)
	Events.resources_updated.emit()
	state_changed.emit()

func trigger_signal_blackout(days: int) -> void:
	signal_active = false
	blackout_days_left = days
	Events.signal_status_changed.emit(false)
	state_changed.emit()

# --- Fase 3 y 4: Validar si el diseño sobrevive la simulación ---
func evaluate_launch_success() -> Dictionary:
	var mass_ok := total_mass <= launch_capacity
	var power_ok := net_power >= 0.0
	var build_ok := build_progress >= 100.0
	var orbit_ok := orbital_alignment >= 50.0
	var survival_ok := food_rations > 0.0

	var overall_success := mass_ok and power_ok and build_ok and orbit_ok and survival_ok

	return {
		"success": overall_success,
		"mass_ok": mass_ok,
		"power_ok": power_ok,
		"build_ok": build_ok,
		"orbit_ok": orbit_ok,
		"survival_ok": survival_ok,
		"science_score": science_score,
		"remaining_budget": budget
	}

func change_phase(new_phase: MissionPhase) -> void:
	current_phase = new_phase
	Events.phase_changed.emit(new_phase)


# ============================================================
# API de la tienda y mantenimiento (consumida por las tabs)
# ============================================================

## ¿Hay una emergencia en Marte que bloquea todo lo demás?
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

	budget -= total                      # se descuenta al instante
	orders_today += 1
	var deliver := current_sol + Catalog.order_delivery_days(items)
	var clean := {}
	for id in items:
		if int(items[id]) > 0:
			clean[id] = int(items[id])
	pending_orders.append({"items": clean, "deliver_sol": deliver})
	_register_calendar_event(deliver, "Llega pedido ($%d)" % total)
	Events.resources_updated.emit()
	state_changed.emit()
	return {"ok": true, "msg": "Pedido confirmado. Llega en el Sol %d." % deliver,
			"total": total, "deliver_sol": deliver}


func buy_supply(id: String) -> Dictionary:
	if is_blocked():
		return {"ok": false, "msg": _blocked_msg()}
	if not signal_active:
		return {"ok": false, "msg": "Sin señal: no puedes comprar suministros."}
	var s := Catalog.get_supply(id)
	if s.is_empty():
		return {"ok": false, "msg": "Suministro desconocido."}
	var en_camino := 0
	for p in pending_supplies:
		if p["id"] == id:
			en_camino += 1
	if int(supply_stock.get(id, 0)) + en_camino >= int(s["max"]):
		return {"ok": false, "msg": "Ya tienes el máximo de %s." % s["nombre"]}
	if budget < int(s["costo"]):
		return {"ok": false, "msg": "No tienes dinero suficiente"}

	budget -= int(s["costo"])
	var deliver := current_sol + int(s["dias"])
	pending_supplies.append({"id": id, "deliver_sol": deliver})
	_register_calendar_event(deliver, "Llega %s" % s["nombre"])
	Events.resources_updated.emit()
	state_changed.emit()
	return {"ok": true, "msg": "%s en camino (Sol %d)." % [s["nombre"], deliver]}


func _register_calendar_event(sol: int, texto: String) -> void:
	# Agrega en Events.gd:  signal calendar_event_added(sol: int, texto: String)
	# Mientras no exista, esto no hace nada.
	if Events.has_signal("calendar_event_added"):
		Events.calendar_event_added.emit(sol, texto)


func _deliver_pending() -> void:
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


# --- Eventos aleatorios ---

func get_faults() -> Array:
	return _fault_sys.get_faults()


func get_workers_info() -> Dictionary:
	return _fault_sys.workers_info()


func _tick_faults() -> void:
	for id in _fault_sys.tick_day(current_sol):
		Events.adverse_event_triggered.emit(str(id))


## Devuelve {ok:bool, msg:String}.
## - Marte: cuesta dinero y CONSUME EL DÍA (avanza el Sol automáticamente).
## - Tierra: asigna un trabajador libre durante N días (requiere señal).
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
		Events.resources_updated.emit()
		state_changed.emit()
		advance_sol()   # día perdido
		return {"ok": true, "msg": "Emergencia resuelta (-$%d). Perdiste el día: ahora es el Sol %d." % [costo, current_sol]}

	# Tierra
	if is_blocked():
		return {"ok": false, "msg": _blocked_msg()}
	if not signal_active:
		return {"ok": false, "msg": "Sin señal: no puedes dar órdenes a la Tierra."}
	var res := _fault_sys.start_earth_repair(id)
	state_changed.emit()
	return res


## Solo para pruebas: fuerza un evento (p. ej. debug_forzar_evento("m_oxigeno")).
func debug_forzar_evento(id: String) -> void:
	_fault_sys.force_activate(id)
	state_changed.emit()
