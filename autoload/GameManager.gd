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
var budget: int = 62000
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

# Claves = ids de res://data/shop_catalog.gd (lo que llega a inventory al recibir un pedido).
const MATERIAL_INFO := {
	"aluminio":   ["Aluminio estructural", "kg"],
	"acero":      ["Acero inoxidable",     "kg"],
	"titanio":    ["Titanio aeroespacial", "kg"],
	"fibra_c":    ["Fibra de carbono",     "kg"],
	"c_guiado":   ["Circuito de guiado",   "u"],
	"c_potencia": ["Módulo de potencia",   "u"],
	"c_enlace":   ["Módulo de enlace",     "u"],
	"c_termico":  ["Sensor térmico",       "u"],
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
		"recipe": {"fibra_c": 10, "c_enlace": 2}, "work": 18,
		"fault": "navegación sin configurar"},
]

var inventory: Dictionary = {}   # lo llena _init_shop_state() con los ids del catálogo
var part_state: Array[int] = [0, 0, 0, 0]
var part_workers: Array[int] = [0, 0, 0, 0]
var part_days_left: Array[float] = [0.0, 0.0, 0.0, 0.0]

# --- Tienda (materiales, circuitos, suministros) ---
var orders_today: int = 0
var pending_orders: Array = []
var supply_stock: Dictionary = {}
var pending_supplies: Array = []

# --- Eventos aleatorios (Marte / Tierra + trabajadores) ---
var _fault_sys := FaultSys.new()


func _ready() -> void:
	_init_shop_state()

func reset_game() -> void:
	current_phase = MissionPhase.DESIGN
	current_sol = 1
	food_rations = 60.0
	signal_active = true
	blackout_days_left = 0

	budget = 62000
	staff_count = 12
	crew_efficiency = 1.0
	build_progress = 0.0

	equipped_parts.clear()
	total_mass = 1000.0
	net_power = 0.0
	science_score = 0
	launch_capacity = 3000.0
	orbital_alignment = 100.0

	inventory.clear()
	supply_stock.clear()
	_init_shop_state()

	part_state = [0, 0, 0, 0]
	part_workers = [0, 0, 0, 0]
	part_days_left = [0.0, 0.0, 0.0, 0.0]

	orders_today = 0
	pending_orders.clear()
	pending_supplies.clear()

	_fault_sys = FaultSys.new()

	Events.sol_advanced.emit(current_sol)
	Events.resources_updated.emit()
	Events.signal_status_changed.emit(true)
	state_changed.emit()


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
	if _fault_sys != null:
		n += _fault_sys.workers_busy()
	return n


func workers_free() -> int:
	return maxi(staff_count - workers_busy(), 0)


func has_materials(index: int) -> bool:
	var recipe: Dictionary = ROCKET_PARTS[index]["recipe"]
	for key in recipe.keys():
		if int(inventory.get(key, 0)) < int(recipe[key]):
			return false
	return true


func is_signal_online() -> bool:
	return signal_active and not tiene_falla("t_antena")


func max_assignable_workers() -> int:
	var free := workers_free()
	if tiene_falla("t_control"):
		return mini(free, 4)
	return free


func fabrication_days(index: int, workers: int) -> int:
	var work := float(ROCKET_PARTS[index]["work"])
	return maxi(1, ceili(work / float(maxi(workers, 1))))


func start_fabrication(index: int, workers: int) -> String:
	if index < 0 or index >= ROCKET_PARTS.size():
		return "Pieza inválida."
	if part_state[index] != PartState.PENDING:
		return "Esa pieza ya está en fabricación o terminada."
	if not is_signal_online():
		return "Pérdida de comunicación: no puedes enviar órdenes a la Tierra."
	if tiene_falla("t_energia"):
		return "Corte de energía en la Tierra: la planta está sin electricidad."
	if tiene_falla("t_software"):
		return "Falla de software: servidor de diseño fuera de línea."
	if workers < 1:
		return "Asigna al menos un trabajador."
	if workers > max_assignable_workers():
		return "Falla en centro de control: máximo %d trabajadores por pieza." % max_assignable_workers()
	if not has_materials(index):
		return "Faltan insumos. Compra y recibe los materiales antes de fabricar."
	var recipe: Dictionary = ROCKET_PARTS[index]["recipe"]
	for key in recipe.keys():
		inventory[key] = int(inventory.get(key, 0)) - int(recipe[key])
	part_state[index] = PartState.IN_PROGRESS
	part_workers[index] = workers
	part_days_left[index] = float(fabrication_days(index, workers))
	var dia_pieza := mini(current_sol + ceili(part_days_left[index]), MAX_SOLS)
	var nombre_pieza := str(ROCKET_PARTS[index].get("nombre", ROCKET_PARTS[index].get("name", "Pieza")))
	GestorCalendario.obtener().cancelar_por_dato("fabricacion_idx", index)
	GestorCalendario.obtener().registrar_evento(
		dia_pieza,
		"Pieza lista: %s" % nombre_pieza,
		GestorCalendario.TIPO_FABRICACION,
		"Fabricación con %d trabajadores" % workers,
		{"fabricacion_idx": index}
	)
	Events.part_state_changed.emit(index)
	state_changed.emit()
	Events.resources_updated.emit()
	state_changed.emit()
	return ""


# Motivo por el que la fabricación en curso no avanza (o avanza más lento). "" = avanza normal.
func fabrication_block_reason() -> String:
	if tiene_falla("t_energia"):
		return "Corte de energía en la Tierra: ensamblaje detenido. Repáralo en Mantenimiento."
	if tiene_falla("earth_crane"):
		return "Grúa de ensamblaje averiada: la construcción está detenida. Repárala en Mantenimiento."
	var sueldos := int(staff_count * 35)
	if budget < sueldos:
		return "Sin dinero para pagar al personal (%d USD por sol): la fabricación está detenida." % sueldos
	if not is_signal_online():
		return "Sin comunicación con la Tierra: el personal trabaja al 40%."
	if tiene_falla("t_control"):
		return "Centro de control caído: fabricación al 50% y máx. 4 trabajadores por pieza."
	if tiene_falla("earth_burnout"):
		return "Personal agotado: la fabricación avanza a la mitad de velocidad."
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
	for i in ROCKET_PARTS.size():
		if part_state[i] != PartState.IN_PROGRESS:
			continue
		part_days_left[i] -= speed
		if part_days_left[i] <= 0.0:
			part_days_left[i] = 0.0
			part_state[i] = PartState.READY
			part_workers[i] = 0
			GestorCalendario.obtener().cancelar_por_dato("fabricacion_idx", i)
			_sync_build_progress()
			Events.part_state_changed.emit(i)


# --- Lanzamiento ---
func arrival_sol() -> int:
	return current_sol + FLIGHT_DAYS


func food_left_on_arrival() -> float:
	return food_rations - float(FLIGHT_DAYS)


func launch_window_days_left() -> int:
	return maxi(0, MAX_SOLS - current_sol)


func launch_block_reason() -> String:
	if current_sol > MAX_SOLS:
		return "La ventana de lanzamiento se cerró después del Sol %d." % MAX_SOLS
	if systems_ready() < ROCKET_PARTS.size():
		return "Faltan sistemas por fabricar. Revisa el modo simulación."
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
	if current_sol <= MAX_SOLS:
		rows.append({"name": "Ventana de despegue", "ok": true,
			"text": "OK / abierta hasta el Sol %d (quedan %d Soles)" % [MAX_SOLS, launch_window_days_left()]})
	else:
		rows.append({"name": "Ventana de despegue", "ok": false,
			"text": "CERRADA / se superó el límite del Sol %d" % MAX_SOLS})
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
		return {"success": false, "launch_sol": current_sol, "sols_left": launch_window_days_left()}
	var sols_left := launch_window_days_left()
	var result := {"success": true, "launch_sol": current_sol, "sols_left": sols_left}
	change_phase(MissionPhase.EVALUATION)
	Events.resources_updated.emit()
	state_changed.emit()
	Events.launch_finished.emit(true, current_sol, float(sols_left))
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
	current_sol += 1
	orders_today = 0          # reinicia el límite diario de pedidos
	if tiene_falla("t_proveedor"):
		_delay_pending_deliveries()
	else:
		_deliver_pending()
	_tick_faults()            # avanza reparaciones y sortea eventos nuevos
	food_rations -= 1.0 * ration_multiplier

	# Verificar derrota por falta de comida (Botiquines otorgan +2 Soles extra cada uno)
	if food_rations <= 0.0:
		if consume_supply("botiquin", 1):
			food_rations = 2.0
			GestorCalendario.obtener().registrar_evento(
				current_sol,
				"Botiquín usado: +2 Soles de soporte vital",
				GestorCalendario.TIPO_MANTENIMIENTO,
				"Raciones de emergencia médicas activadas al agotarse la comida."
			)
		else:
			state_changed.emit()
			change_phase(MissionPhase.EVALUATION)
			return

	# Gestionar días sin señal
	if blackout_days_left > 0:
		blackout_days_left -= 1
		if blackout_days_left == 0:
			signal_active = true
			Events.signal_status_changed.emit(is_signal_online())

	# Avance de tus subordinados en la Tierra
	var daily_cost := int(staff_count * 35 * work_speed)
	if budget >= daily_cost:
		budget -= daily_cost
		if not tiene_falla("t_energia"):
			var actual_efficiency := crew_efficiency if is_signal_online() else crew_efficiency * 0.4
			if tiene_falla("t_control"):
				actual_efficiency *= 0.5
			_tick_fabrication(work_speed * actual_efficiency)

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
	var survival_ok := current_sol <= MAX_SOLS

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
	if not is_signal_online():
		return {"ok": false, "msg": "Sin comunicación con la Tierra: no puedes hacer pedidos."}
	if tiene_falla("t_proveedor"):
		return {"ok": false, "msg": "Retraso de proveedor activo: resuélvelo en Mantenimiento."}
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
	if is_blocked():
		return {"ok": false, "msg": _blocked_msg()}
	if not is_signal_online():
		return {"ok": false, "msg": "Sin comunicación con la Tierra: no puedes comprar suministros."}
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
	var dia_valido := clampi(sol, 1, MAX_SOLS)
	GestorCalendario.obtener().registrar_evento(
		dia_valido,
		texto,
		GestorCalendario.TIPO_MATERIAL,
		"Entrega programada",
		{"entrega_sol": dia_valido}
	)
	if Events.has_signal("calendar_event_added"):
		Events.calendar_event_added.emit(sol, texto)


func _delay_pending_deliveries() -> void:
	for o in pending_orders:
		var old_sol := int(o["deliver_sol"])
		var new_sol := old_sol + 1
		o["deliver_sol"] = new_sol
		GestorCalendario.obtener().cancelar_por_dato("entrega_sol", old_sol)
		_register_calendar_event(new_sol, "Pedido retrasado ($%d)" % Catalog.order_total(o["items"]))
	for p in pending_supplies:
		var old_sol := int(p["deliver_sol"])
		var new_sol := old_sol + 1
		p["deliver_sol"] = new_sol
		var s := Catalog.get_supply(str(p["id"]))
		GestorCalendario.obtener().cancelar_por_dato("entrega_sol", old_sol)
		_register_calendar_event(new_sol, "%s retrasado" % str(s.get("nombre", p["id"])))


func _deliver_pending() -> void:
	GestorCalendario.obtener().cancelar_por_dato("entrega_sol", current_sol)
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


func tiene_falla(id_falla: String) -> bool:
	var f := _fault_sys.find_fault(id_falla)
	return bool(f.get("activa", false))


func get_workers_info() -> Dictionary:
	return {"total": staff_count, "busy": workers_busy(), "free": workers_free()}


func get_supply_count(id: String) -> int:
	return int(supply_stock.get(id, 0))


func consume_supply(id: String, amount: int = 1) -> bool:
	var cur := get_supply_count(id)
	if cur < amount:
		return false
	supply_stock[id] = cur - amount
	Events.resources_updated.emit()
	state_changed.emit()
	return true


func get_launch_preview_seconds() -> float:
	return 1.6 + 0.45 * float(get_supply_count("enlace"))


func _tick_faults() -> void:
	var tiene_humo := get_supply_count("humo") > 0
	var triggered: Array = _fault_sys.tick_day(current_sol, tiene_humo)

	# Si se activó una emergencia marciana, limpiar su alerta previa del calendario
	for id in triggered:
		var sid := str(id)
		var f_act := _fault_sys.find_fault(sid)
		if str(f_act.get("tipo", "")) == "marte":
			GestorCalendario.obtener().cancelar_por_dato("alerta_sensor", sid)

		# Módulos de enlace absorben automáticamente una caída de antena
		if sid == "t_antena" and consume_supply("enlace", 1):
			f_act["activa"] = false
			GestorCalendario.obtener().registrar_evento(
				current_sol,
				"Módulo de enlace absorbió caída de antena",
				GestorCalendario.TIPO_MANTENIMIENTO,
				"Se consumió 1 módulo de enlace para mantener la señal sin interrupciones."
			)
			continue

		Events.adverse_event_triggered.emit(sid)

	# Detector de humo: registra alerta temprana en calendario 1 Sol antes
	if _fault_sys.pending_mars_id != "":
		var pf := _fault_sys.find_fault(_fault_sys.pending_mars_id)
		var titulo_alerta := str(pf.get("titulo", "Emergencia"))
		var dia_alerta := mini(current_sol + 1, MAX_SOLS)
		GestorCalendario.obtener().cancelar_por_dato("alerta_sensor", _fault_sys.pending_mars_id)
		GestorCalendario.obtener().registrar_evento(
			dia_alerta,
			"Alerta sensor: " + titulo_alerta,
			GestorCalendario.TIPO_MANTENIMIENTO,
			"El detector de humo anticipó una anomalía inminente en la base de Marte.",
			{"alerta_sensor": _fault_sys.pending_mars_id}
		)

	for f in _fault_sys.get_faults():
		if str(f.get("tipo", "")) == "tierra" and not bool(f.get("en_reparacion", false)):
			GestorCalendario.obtener().cancelar_por_dato("reparacion_id", str(f.get("id", "")))


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
		var pierde_dia := true
		var nota_suministro := ""

		# Extintores: -50% costo y conserva el Sol en Apagón o Daño estructural
		if id in ["m_apagon", "m_estructura"] and get_supply_count("extintor") > 0:
			var costo_desc := int(round(costo * 0.5))
			if budget < costo_desc:
				return {"ok": false, "msg": "No tienes dinero suficiente"}
			consume_supply("extintor", 1)
			costo = costo_desc
			pierde_dia = false
			nota_suministro = " (Extintor usado: -50% costo y conservas el Sol)"
		# Botiquines: -50% costo en Fuga de agua o Daño estructural
		elif id in ["m_agua", "m_estructura"] and get_supply_count("botiquin") > 0:
			var costo_desc := int(round(costo * 0.5))
			if budget < costo_desc:
				return {"ok": false, "msg": "No tienes dinero suficiente"}
			consume_supply("botiquin", 1)
			costo = costo_desc
			nota_suministro = " (Botiquín usado: -50% costo)"
		else:
			if budget < costo:
				return {"ok": false, "msg": "No tienes dinero suficiente"}

		budget -= costo
		_fault_sys.resolve_mars(id)
		Events.resources_updated.emit()
		state_changed.emit()
		if pierde_dia:
			advance_sol()   # día perdido
			return {"ok": true, "msg": "Emergencia resuelta (-$%d)%s. Perdiste el día: ahora es el Sol %d." % [costo, nota_suministro, current_sol]}
		return {"ok": true, "msg": "Emergencia resuelta (-$%d)%s. Conservas el Sol %d." % [costo, nota_suministro, current_sol]}

	# Tierra
	if is_blocked():
		return {"ok": false, "msg": _blocked_msg()}
	if not is_signal_online() and id != "t_antena":
		return {"ok": false, "msg": "Sin comunicación: repara primero la antena terrestre."}
	var res := _fault_sys.start_earth_repair(id, workers_free())
	if bool(res.get("ok", false)):
		var dia_rep := mini(current_sol + int(f.get("dias_rep", 1)), MAX_SOLS)
		var titulo_falla := str(f.get("titulo", id))
		GestorCalendario.obtener().cancelar_por_dato("reparacion_id", id)
		GestorCalendario.obtener().registrar_evento(
			dia_rep,
			"Reparado: %s" % titulo_falla,
			GestorCalendario.TIPO_MANTENIMIENTO,
			"Reparación en base terrestre",
			{"reparacion_id": id}
		)
	Events.resources_updated.emit()
	state_changed.emit()
	return res


## Solo para pruebas: fuerza un evento (p. ej. debug_forzar_evento("m_apagon")).
func debug_forzar_evento(id: String) -> void:
	_fault_sys.force_activate(id)
	state_changed.emit()
