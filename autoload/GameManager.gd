extends Node

const Catalog = preload("res://data/shop_catalog.gd")

signal state_changed

enum MissionPhase { DESIGN, MANAGEMENT, SIMULATION, EVALUATION }
var current_phase: MissionPhase = MissionPhase.DESIGN

# --- Supervivencia en Marte y Tiempo Límite ---
const MAX_SOLS: int = 60
var current_sol: int = 1
var food_rations: float = 60.0
var signal_active: bool = true
var blackout_days_left: int = 0

# --- Administración de Recursos y Subordinados ---
var budget: int = 1000
var staff_count: int = 12
var crew_efficiency: float = 1.0
var build_progress: float = 0.0

# --- Métricas de Ingeniería ---
var equipped_parts: Array[SpacecraftPart] = []
var total_mass: float = 1000.0
var net_power: float = 0.0
var science_score: int = 0
var launch_capacity: float = 3000.0
var orbital_alignment: float = 100.0

# =====================================================================
# MÓDULOS DISEÑO (03) Y LANZAMIENTO (04)
# =====================================================================
enum PartState { PENDING, IN_PROGRESS, READY }

const FLIGHT_DAYS: int = 8

const MATERIAL_INFO := {
	"aluminio":   ["Aluminio 6061", "kg"],
	"titanio":    ["Titanio Ti-6Al", "kg"],
	"acero":      ["Acero inoxidable", "kg"],
	"fibra":      ["Fibra de carbono", "kg"],
	"c_guiado":   ["Circuito de guiado", "u"],
	"c_potencia": ["Módulo de potencia", "u"],
	"c_enlace":   ["Módulo de enlace", "u"],
	"c_termico":  ["Sensor térmico", "u"],
}

const ROCKET_PARTS := [
	{"id": "fuselaje", "name": "Fuselaje principal",
		"recipe": {"aluminio": 40, "c_guiado": 2}, "work": 30,
		"fault": "estructura sin fabricar"},
	{"id": "motor", "name": "Motor de impulso",
		"recipe": {"titanio": 20, "c_potencia": 1}, "work": 24,
		"fault": "no hay sistema de empuje"},
	{"id": "deposito", "name": "Depósito de combustible",
		"recipe": {"acero": 30, "c_termico": 1}, "work": 24,
		"fault": "no hay reserva de combustible"},
	{"id": "guiado", "name": "Sistema de guiado",
		"recipe": {"fibra": 10, "c_enlace": 2}, "work": 18,
		"fault": "navegación sin configurar"},
]

var inventory: Dictionary = {
	"aluminio": 0, "titanio": 0, "acero": 0, "fibra": 0,
	"c_guiado": 0, "c_potencia": 0, "c_enlace": 0, "c_termico": 0,
}
var part_state: Array[int] = [0, 0, 0, 0]
var part_workers: Array[int] = [0, 0, 0, 0]
var part_days_left: Array[float] = [0.0, 0.0, 0.0, 0.0]

# --- Tienda (materiales, circuitos, suministros) ---
var orders_today: int = 0
var pending_orders: Array = []
var supply_stock: Dictionary = {}
var pending_supplies: Array = []

# --- Sistema de Mantenimiento (9 fallas reales) ---
var turno_marte_usado: bool = false

var _faults: Array = [
	{
		"id": "mars_antenna",
		"ubicacion": "MARTE",
		"titulo": "Antena Desalineada",
		"desc": "Corta la señal con la Tierra hasta salir a recalibrar el plato.",
		"costo_dinero": 0,
		"costo_turno": true,
		"activa": false
	},
	{
		"id": "mars_solar_dust",
		"ubicacion": "MARTE",
		"titulo": "Polvo en Paneles Solares",
		"desc": "Modo ahorro: apaga la cámara de la Tierra y bloquea las Notas.",
		"costo_dinero": 0,
		"costo_turno": true,
		"activa": false
	},
	{
		"id": "mars_telemetry",
		"ubicacion": "MARTE",
		"titulo": "Interferencia en Telemetría",
		"desc": "Oculta el porcentaje real de avance del cohete.",
		"costo_dinero": 50,
		"costo_turno": false,
		"activa": false
	},
	{
		"id": "mars_clock_drift",
		"ubicacion": "MARTE",
		"titulo": "Fallo en Reloj Orbital",
		"desc": "Desincronización: cada jornada consume 2 Soles del plazo.",
		"costo_dinero": 0,
		"costo_turno": true,
		"activa": false
	},
	{
		"id": "earth_crane",
		"ubicacion": "TIERRA",
		"titulo": "Grúa de Ensamblaje Averiada",
		"desc": "Los chalanes no pueden mover piezas. Construcción detenida.",
		"costo_dinero": 150,
		"costo_turno": false,
		"activa": false
	},
	{
		"id": "earth_weld",
		"ubicacion": "TIERRA",
		"titulo": "Soldadura Defectuosa en Tanque",
		"desc": "Microfractura en el fuselaje. Riesgo crítico en el lanzamiento.",
		"costo_dinero": 120,
		"costo_turno": false,
		"activa": false
	},
	{
		"id": "earth_burnout",
		"ubicacion": "TIERRA",
		"titulo": "Agotamiento de los Chalanes",
		"desc": "El personal en Tierra está exhausto y avanza más lento.",
		"costo_dinero": 100,
		"costo_turno": false,
		"activa": false
	},
	{
		"id": "earth_shortcircuit",
		"ubicacion": "TIERRA",
		"titulo": "Cortocircuito en Banco de Pruebas",
		"desc": "El balance energético de la nave pierde -15 puntos.",
		"costo_dinero": 90,
		"costo_turno": false,
		"activa": false
	},
	{
		"id": "earth_cleanroom",
		"ubicacion": "TIERRA",
		"titulo": "Polvo en la Sala Limpia",
		"desc": "Contaminación en sensores: pierdes -5 puntos de ciencia por Sol.",
		"costo_dinero": 75,
		"costo_turno": false,
		"activa": false
	}
]


func _ready() -> void:
	_init_shop_state()


func _init_shop_state() -> void:
	for it in Catalog.all_items():
		inventory[it["id"]] = int(inventory.get(it["id"], 0))
	for s in Catalog.SUPPLIES:
		supply_stock[s["id"]] = int(supply_stock.get(s["id"], 0))


func add_material(key: String, amount: int) -> void:
	inventory[key] = int(inventory.get(key, 0)) + amount
	Events.resources_updated.emit()
	state_changed.emit()


func workers_busy() -> int:
	var n := 0
	for i in ROCKET_PARTS.size():
		if part_state[i] == PartState.IN_PROGRESS:
			n += part_workers[i]
	return n


func workers_free() -> int:
	return maxi(staff_count - workers_busy(), 0)


func has_materials(index: int) -> bool:
	var recipe: Dictionary = ROCKET_PARTS[index]["recipe"]
	for key in recipe.keys():
		if int(inventory.get(key, 0)) < int(recipe[key]):
			return false
	return true


func fabrication_days(index: int, workers: int) -> int:
	var work := float(ROCKET_PARTS[index]["work"])
	return maxi(1, ceili(work / float(maxi(workers, 1))))


func start_fabrication(index: int, workers: int) -> String:
	if index < 0 or index >= ROCKET_PARTS.size():
		return "Pieza inválida."
	if part_state[index] != PartState.PENDING:
		return "Esa pieza ya está en fabricación o terminada."
	if workers < 1:
		return "Asigna al menos un trabajador."
	if workers > workers_free():
		return "No hay suficientes trabajadores libres."
	if not has_materials(index):
		return "Faltan insumos. Compra y recibe los materiales antes de fabricar."
	var recipe: Dictionary = ROCKET_PARTS[index]["recipe"]
	for key in recipe.keys():
		inventory[key] = int(inventory.get(key, 0)) - int(recipe[key])
	part_state[index] = PartState.IN_PROGRESS
	part_workers[index] = workers
	part_days_left[index] = float(fabrication_days(index, workers))
	Events.part_state_changed.emit(index)
	Events.resources_updated.emit()
	state_changed.emit()
	return ""


func systems_ready() -> int:
	var n := 0
	for s in part_state:
		if s == PartState.READY:
			n += 1
	return n


func _sync_build_progress() -> void:
	build_progress = 100.0 * float(systems_ready()) / float(ROCKET_PARTS.size())


func _tick_fabrication(speed: float) -> void:
	if tiene_falla("earth_crane"):
		return
	var mult := 0.5 if tiene_falla("earth_burnout") else 1.0
	for i in ROCKET_PARTS.size():
		if part_state[i] != PartState.IN_PROGRESS:
			continue
		part_days_left[i] -= speed * mult
		if part_days_left[i] <= 0.0:
			part_days_left[i] = 0.0
			part_state[i] = PartState.READY
			part_workers[i] = 0
			_sync_build_progress()
			Events.part_state_changed.emit(i)


# --- Lanzamiento ---
func arrival_sol() -> int:
	return current_sol + FLIGHT_DAYS


func food_left_on_arrival() -> float:
	return food_rations - float(FLIGHT_DAYS)


func launch_block_reason() -> String:
	if systems_ready() < ROCKET_PARTS.size():
		return "Faltan sistemas por fabricar. Revisa el modo simulación."
	if food_left_on_arrival() <= 0.0:
		return "La comida no alcanza para los %d días de vuelo." % FLIGHT_DAYS
	var ev := evaluate_launch_success()
	if not ev["mass_ok"]:
		return "La masa total supera la capacidad del lanzador."
	if not ev["power_ok"]:
		return "El balance energético es negativo."
	if not ev["orbit_ok"]:
		return "La alineación orbital se degradó demasiado."
	if not ev["success"]:
		return "La configuración no supera la evaluación."
	return ""


func can_launch() -> bool:
	return launch_block_reason() == ""


func simulate_launch() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i in ROCKET_PARTS.size():
		var p: Dictionary = ROCKET_PARTS[i]
		match part_state[i]:
			PartState.READY:
				rows.append({"name": p["name"], "ok": true, "text": "OK / sistema operativo"})
			PartState.IN_PROGRESS:
				rows.append({"name": p["name"], "ok": false,
					"text": "FALTA / en fabricación, quedan %d días" % ceili(part_days_left[i])})
			_:
				rows.append({"name": p["name"], "ok": false, "text": "FALTA / " + String(p["fault"])})
	if food_left_on_arrival() <= 0.0:
		rows.append({"name": "Reservas de comida", "ok": false,
			"text": "FALTA / no alcanzan para %d días de vuelo" % FLIGHT_DAYS})
	var ev := evaluate_launch_success()
	if not ev["mass_ok"]:
		rows.append({"name": "Masa total", "ok": false, "text": "FALTA / supera la capacidad del lanzador"})
	if not ev["power_ok"]:
		rows.append({"name": "Energía", "ok": false, "text": "FALTA / balance energético negativo"})
	if not ev["orbit_ok"]:
		rows.append({"name": "Ventana orbital", "ok": false, "text": "FALTA / alineación degradada"})
	return rows


func launch_real() -> Dictionary:
	if not can_launch():
		return {"success": false, "arrival": arrival_sol(), "food_left": food_left_on_arrival()}
	current_sol += FLIGHT_DAYS
	food_rations -= float(FLIGHT_DAYS)
	var result := {"success": true, "arrival": current_sol, "food_left": food_rations}
	change_phase(MissionPhase.EVALUATION)
	Events.sol_advanced.emit(current_sol)
	Events.resources_updated.emit()
	state_changed.emit()
	Events.launch_finished.emit(true, current_sol, food_rations)
	return result


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
	var avance_soles := 2 if tiene_falla("mars_clock_drift") else 1
	current_sol += avance_soles
	orders_today = 0
	turno_marte_usado = false
	_deliver_pending()
	_roll_random_faults()
	food_rations -= 1.0 * ration_multiplier

	if food_rations <= 0.0:
		state_changed.emit()
		change_phase(MissionPhase.EVALUATION)
		return

	if blackout_days_left > 0:
		blackout_days_left -= 1
		if blackout_days_left == 0 and not tiene_falla("mars_antenna"):
			signal_active = true
			Events.signal_status_changed.emit(true)

	var daily_cost := int(staff_count * 5 * work_speed)
	if budget >= daily_cost:
		budget -= daily_cost
		var actual_efficiency := crew_efficiency if signal_active else crew_efficiency * 0.4
		_tick_fabrication(work_speed * actual_efficiency)

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
# API de la tienda y mantenimiento
# ============================================================
func get_estado_accion() -> String:
	if turno_marte_usado:
		return "Acción física de hoy en Marte ya utilizada."
	return "Sin acción física en curso en Marte."


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

	budget -= total
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


func get_faults() -> Array:
	return _faults


func tiene_falla(id_falla: String) -> bool:
	for f in _faults:
		if f["id"] == id_falla and f["activa"]:
			return true
	return false


func reparar_falla(id: String) -> bool:
	for f in _faults:
		if f["id"] == id and f["activa"]:
			if f["ubicacion"] == "TIERRA":
				if not signal_active or budget < int(f["costo_dinero"]):
					return false
				budget -= int(f["costo_dinero"])
			elif f["ubicacion"] == "MARTE":
				if bool(f["costo_turno"]) and turno_marte_usado:
					return false
				if budget < int(f["costo_dinero"]):
					return false
				budget -= int(f["costo_dinero"])
				if bool(f["costo_turno"]):
					turno_marte_usado = true
				if f["id"] == "mars_antenna":
					signal_active = true
					Events.signal_status_changed.emit(true)
			f["activa"] = false
			Events.resources_updated.emit()
			state_changed.emit()
			return true
	return false


func _roll_random_faults() -> void:
	var activas := 0
	var disponibles: Array = []
	for f in _faults:
		if f["activa"]:
			activas += 1
		else:
			disponibles.append(f)
	if activas < 4 and disponibles.size() > 0 and randf() < 0.40:
		var elegida: Dictionary = disponibles.pick_random()
		elegida["activa"] = true
		if elegida["id"] == "mars_antenna":
			signal_active = false
			Events.signal_status_changed.emit(false)
