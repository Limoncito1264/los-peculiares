extends Node

enum MissionPhase { DESIGN, MANAGEMENT, SIMULATION, EVALUATION }
var current_phase: MissionPhase = MissionPhase.DESIGN

# --- Supervivencia en Marte y Tiempo Límite ---
const MAX_SOLS: int = 60
var current_sol: int = 1
var food_rations: float = 60.0        # Suministros para 60 días
var has_signal: bool = true           # Estado de comunicación Tierra-Marte
var blackout_days_left: int = 0

# --- Administración de Recursos y Subordinados ---
var budget: int = 1000                # Dinero disponible
var staff_count: int = 10             # Personal asignado en la Tierra
var crew_efficiency: float = 1.0      # Afectado por tus órdenes o falta de señal
var build_progress: float = 0.0       # 0.0 a 100.0% de construcción de la nave (ahora = piezas listas / total)

# --- Métricas de Ingeniería (Trade-offs) ---
var equipped_parts: Array[SpacecraftPart] = []
var total_mass: float = 1000.0        # Masa base de la cápsula
var net_power: float = 0.0            # Balance energético
var science_score: int = 0            # Instrumentos científicos equipados
var launch_capacity: float = 3000.0   # Masa máxima que soporta el vehículo elegido
var orbital_alignment: float = 100.0  # Se degrada si te pasas de la ventana de 60 días


# =====================================================================
# MÓDULOS DISEÑO (03) Y LANZAMIENTO (04)  — NUEVO
# =====================================================================
enum PartState { PENDING, IN_PROGRESS, READY }

const FLIGHT_DAYS: int = 8   # [Figma] "VUELO ESTIMADO 8 DÍAS"

# Nombre y unidad de cada insumo. Las claves deben coincidir con las de la tienda (tab_shop).
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

# "work" = trabajador-días necesarios (30 con 6 trabajadores = 5 días, como en Figma).
# OJO: solo la receta del fuselaje sale de Figma; el resto son PLACEHOLDERS.
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

# Insumos recibidos (la tienda debe llamar a add_material cuando llega un pedido).
var inventory: Dictionary = {
	"aluminio": 0, "titanio": 0, "acero": 0, "fibra": 0,
	"c_guiado": 0, "c_potencia": 0, "c_enlace": 0, "c_termico": 0,
}
var part_state: Array[int] = [0, 0, 0, 0]
var part_workers: Array[int] = [0, 0, 0, 0]
var part_days_left: Array[float] = [0.0, 0.0, 0.0, 0.0]


func add_material(key: String, amount: int) -> void:
	inventory[key] = int(inventory.get(key, 0)) + amount
	Events.resources_updated.emit()


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


# Devuelve "" si todo salió bien, o el mensaje de error para mostrar en la UI.
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
	return ""


func systems_ready() -> int:
	var n := 0
	for s in part_state:
		if s == PartState.READY:
			n += 1
	return n


func _sync_build_progress() -> void:
	build_progress = 100.0 * float(systems_ready()) / float(ROCKET_PARTS.size())


# Se llama desde advance_sol(); speed = eficiencia del día (menor sin señal).
func _tick_fabrication(speed: float) -> void:
	for i in ROCKET_PARTS.size():
		if part_state[i] != PartState.IN_PROGRESS:
			continue
		part_days_left[i] -= speed
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


# "" = se puede lanzar; si no, el motivo para mostrar en la UI.
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


# Diagnóstico de la simulación. No consume nada.
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


# Lanzamiento real e irreversible.
func launch_real() -> Dictionary:
	if not can_launch():
		return {"success": false, "arrival": arrival_sol(), "food_left": food_left_on_arrival()}
	current_sol += FLIGHT_DAYS
	food_rations -= float(FLIGHT_DAYS)
	var result := {"success": true, "arrival": current_sol, "food_left": food_rations}
	change_phase(MissionPhase.EVALUATION)
	Events.sol_advanced.emit(current_sol)
	Events.resources_updated.emit()
	Events.launch_finished.emit(true, current_sol, food_rations)
	return result


# =====================================================================
# CÓDIGO EXISTENTE
# =====================================================================

# --- Fase 1: Equipar piezas y calcular trade-offs ---
func equip_part(part: SpacecraftPart) -> bool:
	if budget < part.budget_cost:
		return false

	budget -= part.budget_cost
	equipped_parts.append(part)
	recalculate_engineering_stats()
	Events.resources_updated.emit()
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
	food_rations -= 1.0 * ration_multiplier

	# Verificar derrota por falta de comida
	if food_rations <= 0.0:
		change_phase(MissionPhase.EVALUATION)
		return

	# Gestionar días sin señal
	if blackout_days_left > 0:
		blackout_days_left -= 1
		if blackout_days_left == 0:
			has_signal = true
			Events.signal_status_changed.emit(true)

	# Avance de tus subordinados en la Tierra
	var daily_cost := int(staff_count * 5 * work_speed)
	if budget >= daily_cost:
		budget -= daily_cost
		# Sin señal, los subordinados trabajan con menor eficiencia por falta de supervisión
		var actual_efficiency := crew_efficiency if has_signal else crew_efficiency * 0.4
		# CAMBIO: antes aquí se sumaba a build_progress; ahora el avance es por pieza.
		_tick_fabrication(work_speed * actual_efficiency)

	# Penalización por restricciones orbitales si se pasan los 60 días
	if current_sol > MAX_SOLS:
		orbital_alignment -= 15.0

	Events.sol_advanced.emit(current_sol)
	Events.resources_updated.emit()

func trigger_signal_blackout(days: int) -> void:
	has_signal = false
	blackout_days_left = days
	Events.signal_status_changed.emit(false)

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
