extends Node

signal sol_advanced(new_sol: int)
signal resources_updated()
signal signal_status_changed(is_online: bool)
signal adverse_event_triggered(event_id: String)
signal phase_changed(new_phase: int)

# Módulos Diseño y Lanzamiento
signal part_state_changed(part_index: int)
signal launch_finished(success: bool, arrival_sol: int, food_left: float)

# Módulo Calendario / Tienda
signal calendar_event_added(sol: int, texto: String)
