extends Node

signal sol_advanced(new_sol: int)
signal resources_updated()
signal signal_status_changed(is_online: bool)
signal adverse_event_triggered(event_id: String)
signal phase_changed(new_phase: int)
signal calendar_event_added(sol: int, texto: String)
