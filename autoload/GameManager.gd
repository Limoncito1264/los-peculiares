extends Node

# Carga directa del catálogo (no depende del caché de class_name del editor)
const Catalog = preload("res://data/shop_catalog.gd")

signal state_changed   # NUEVO: las vistas (tabs) se refrescan con esta señal

enum MissionPhase { DESIGN, MANAGEMENT, SIMULATION, EVALUATION }
var current_phase: MissionPhase = MissionPhase.DESIGN

# --- Supervivencia en Marte y Tiempo Límite ---
const MAX_SOLS: int = 60
var current_sol: int = 1
var food_rations: float = 60.0        # Suministros para 60 días
# RENOMBRADO: antes "has_signal". Choca con Object.has_signal() de Godot.
# Haz Ctrl+Shift+F de "has_signal" en el proyecto y cambia los usos de GameManager.has_signal.
var signal_active: bool = true        # Estado de comunicación Tierra-Marte
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

# --- NUEVO: Tienda (materiales, circuitos, suministros) ---
var orders_today: int = 0
var inventory: Dictionary = {}        # id -> cantidad en almacén
var pending_orders: Array = []        # [{items:{id:qty}, deliver_sol:int}]
var supply_stock: Dictionary = {}     # id -> reserva
var pending_supplies: Array = []      # [{id, deliver_sol}]

# --- NUEVO: Fallas aleatorias (PLACEHOLDER: reemplaza por la lógica del Tech Lead) ---
var _faults: Array = [
	{"id": "f1", "titulo": "Fuga de oxígeno",         "desc": "Presión cayendo en el módulo habitable.", "prob": 0.05, "activa": false},
	{"id": "f2", "titulo": "Falla eléctrica",         "desc": "Cortocircuito en el bus principal.",      "prob": 0.08, "activa": false},
	{"id": "f3", "titulo": "Pérdida de comunicación", "desc": "Antena de enlace desalineada.",           "prob": 0.07, "activa": false},
	{"id": "f4", "titulo": "Tormenta de polvo",       "desc": "Paneles solares cubiertos de polvo.",     "prob": 0.10, "activa": false},
	{"id": "f5", "titulo": "Sobrecalentamiento",      "desc": "Radiador térmico fuera de rango.",        "prob": 0.06, "activa": false},
	{"id": "f6", "titulo": "Fuga de agua",            "desc": "Pérdida en el reciclador de agua.",       "prob": 0.04, "activa": false},
	{"id": "f7", "titulo": "Falla de software",       "desc": "Computadora de a bordo reiniciándose.",   "prob": 0.09, "activa": false},
	{"id": "f8", "titulo": "Daño estructural",        "desc": "Micrometeorito impactó el casco.",        "prob": 0.03, "activa": false},
	{"id": "f9", "titulo": "Falla de sensores",       "desc": "Lecturas ambientales inconsistentes.",    "prob": 0.07, "activa": false},
]


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
	orders_today = 0          # NUEVO: reinicia el límite diario de pedidos
	_deliver_pending()        # NUEVO: entrega pedidos y suministros vencidos
	_roll_random_faults()     # NUEVO: sorteo diario de fallas
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
# NUEVO: API de la tienda y mantenimiento (consumida por las tabs)
# ============================================================

func get_estado_accion() -> String:
	return "Sin acción física en curso en Marte."   # conecta con tu lógica real


func place_order(items: Dictionary) -> Dictionary:
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
	# Tu Events.gd aún no tiene señal de calendario. Agrega en Events.gd:
	#   signal calendar_event_added(sol: int, texto: String)
	# y tu calendario se conecta a ella. Mientras no exista, esto no hace nada.
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


# --- Fallas (PLACEHOLDER: sustituye por la lógica real del Tech Lead) ---

func get_faults() -> Array:
	return _faults


func reparar_falla(id: String) -> bool:
	for f in _faults:
		if f["id"] == id and f["activa"]:
			f["activa"] = false
			state_changed.emit()
			return true
	return false


func _roll_random_faults() -> void:
	for f in _faults:
		if not f["activa"] and randf() < float(f["prob"]):
			f["activa"] = true
