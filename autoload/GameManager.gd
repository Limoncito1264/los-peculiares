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
var build_progress: float = 0.0       # 0.0 a 100.0% de construcción de la nave

# --- Métricas de Ingeniería (Trade-offs) ---
var equipped_parts: Array[SpacecraftPart] = []
var total_mass: float = 1000.0        # Masa base de la cápsula
var net_power: float = 0.0            # Balance energético
var science_score: int = 0            # Instrumentos científicos equipados
var launch_capacity: float = 3000.0   # Masa máxima que soporta el vehículo elegido
var orbital_alignment: float = 100.0  # Se degrada si te pasas de la ventana de 60 días

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
		build_progress += (staff_count * 0.25) * work_speed * actual_efficiency
		build_progress = clamp(build_progress, 0.0, 100.0)
	
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
